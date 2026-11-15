//
//  CaptureSessionControls.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

/// The Camera Control's controls of one capture session, called on the session queue only.
protocol CaptureControlsBinding: AnyObject {

    /// Replaces the controls with ones for a newly committed camera.
    func bind(to device: AVCaptureDevice, lenses: [CameraLens], displayMultiplier: CGFloat)
    /// Moves the lens picker to a lens chosen on the screen.
    func selectLens(at index: Int)
}

/// What the Camera Control offers in a flow, and the language of its texts.
struct CaptureControlsSetup: Sendable {
    /// Whether the exposure slider is offered: only where the app lets the user change the exposure.
    let isExposureAdjustable: Bool
    /// The language of the lens picker's titles.
    let localization: FlowLocalization
}

enum CaptureSessionControls {
    /// Called on the session queue.
    typealias Report = @Sendable (CaptureControlEvent) -> Void

    static let logger = Logger.camera("CaptureSessionControls")

    /// The controls for a session, or nil where the system or the hardware has no Camera Control.
    static func make(
        session: AVCaptureSession,
        queue: DispatchQueue,
        setup: CaptureControlsSetup,
        report: @escaping Report
    ) -> (any CaptureControlsBinding)? {
        guard #available(iOS 18.0, *) else {
            logger.info("Camera Control: not supported, controls need iOS 18")
            return nil
        }
        guard session.supportsControls else {
            logger.info("Camera Control: not supported by this device")
            return nil
        }
        return SessionCaptureControls(session: session, queue: queue, setup: setup, report: report)
    }
}

/// Exposure, zoom and lens controls in the stock order, and the overlay state reported as events. The system
/// sliders follow the camera's own zoom and exposure bias; the lens picker is moved by `selectLens(at:)`. A flow
/// that fixed the exposure has no exposure slider.
@available(iOS 18.0, *)
private final class SessionCaptureControls: NSObject, CaptureControlsBinding, @unchecked Sendable {
    private let session: AVCaptureSession
    private let queue: DispatchQueue
    private let setup: CaptureControlsSetup
    private let report: CaptureSessionControls.Report
    private var lensPicker: AVCaptureIndexPicker?
    /// The index last set on the lens picker from the screen, so a change the picker reports back is not taken
    /// for the user's.
    private var programmaticLensIndex: Int?

    private static let lensPickerSymbol = "camera.aperture"

    init(
        session: AVCaptureSession,
        queue: DispatchQueue,
        setup: CaptureControlsSetup,
        report: @escaping CaptureSessionControls.Report
    ) {
        self.session = session
        self.queue = queue
        self.setup = setup
        self.report = report
        super.init()
        session.setControlsDelegate(self, queue: queue)
    }

    func bind(to device: AVCaptureDevice, lenses: [CameraLens], displayMultiplier: CGFloat) {
        dispatchPrecondition(condition: .onQueue(queue))
        session.controls.forEach { session.removeControl($0) }
        lensPicker = nil
        programmaticLensIndex = nil
        var added: [String] = []
        for (name, control) in makeControls(for: device, lenses: lenses, displayMultiplier: displayMultiplier) {
            guard session.controls.count < session.maxControlsCount else { break }
            guard session.canAddControl(control) else {
                let logger = CaptureSessionControls.logger
                logger.error("Camera Control: the session refused the \(name, privacy: .public) control")
                continue
            }
            session.addControl(control)
            added.append(name)
            if let picker = control as? AVCaptureIndexPicker {
                lensPicker = picker
            }
        }
        let names = added.joined(separator: ", ")
        let summary = "\(added.count) of at most \(session.maxControlsCount): \(names)"
        CaptureSessionControls.logger.info("Camera Control: supported, added \(summary, privacy: .public)")
    }

    func selectLens(at index: Int) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let lensPicker, lensPicker.selectedIndex != index else { return }
        guard (0..<lensPicker.numberOfIndexes).contains(index) else {
            let logger = CaptureSessionControls.logger
            logger.error("Camera Control: no lens at index \(index, privacy: .public) in the lens picker")
            return
        }
        programmaticLensIndex = index
        lensPicker.selectedIndex = index
    }

    private func makeControls(
        for device: AVCaptureDevice,
        lenses: [CameraLens],
        displayMultiplier: CGFloat
    ) -> [(name: String, control: AVCaptureControl)] {
        var controls: [(name: String, control: AVCaptureControl)] = []
        let report = report
        let queue = queue
        if setup.isExposureAdjustable, device.minExposureTargetBias < device.maxExposureTargetBias {
            let slider = AVCaptureSystemExposureBiasSlider(device: device) { bias in
                queue.async { report(.exposureBiasChanged(Double(bias))) }
            }
            controls.append((name: "Exposure", control: slider))
        }
        if device.minAvailableVideoZoomFactor < device.maxAvailableVideoZoomFactor {
            let slider = AVCaptureSystemZoomSlider(device: device) { deviceFactor in
                queue.async { report(.zoomChanged(deviceFactor * displayMultiplier)) }
            }
            controls.append((name: "Zoom", control: slider))
        }
        if let picker = makeLensPicker(lenses: lenses) {
            controls.append((name: "Cameras", control: picker))
        }
        return controls
    }

    /// A picker over the lens buttons, on the main lens the session starts with. None for a single lens.
    private func makeLensPicker(lenses: [CameraLens]) -> AVCaptureIndexPicker? {
        guard lenses.count > 1 else { return nil }
        guard let mainIndex = lenses.firstIndex(where: { $0.factor == 1 }) else {
            CaptureSessionControls.logger.error("Camera Control: the lens set has no main lens")
            return nil
        }
        let localization = setup.localization
        let titles = lenses.map { CaptureControlTitle.lens($0, localization) }
        let picker = AVCaptureIndexPicker(
            CaptureControlTitle.lensPicker(localization),
            symbolName: Self.lensPickerSymbol,
            localizedIndexTitles: titles
        )
        picker.setActionQueue(queue) { [weak self] index in
            self?.lensPicked(at: index)
        }
        picker.selectedIndex = mainIndex
        programmaticLensIndex = mainIndex
        return picker
    }

    private func lensPicked(at index: Int) {
        defer { programmaticLensIndex = nil }
        guard index != programmaticLensIndex else { return }
        report(.lensSelected(index: index))
    }
}

@available(iOS 18.0, *)
extension SessionCaptureControls: AVCaptureSessionControlsDelegate {

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        report(.overlayChanged(.shown))
    }

    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        report(.overlayChanged(.fullscreen))
    }

    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        report(.overlayChanged(.shown))
    }

    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        report(.overlayChanged(.hidden))
    }
}
#endif
