//
//  ZoomModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Observation

/// Zoom: the current factor, the lenses and the dial of the running camera, which `PhotoCameraModel` hands over
/// whenever a camera has started.
@MainActor
@Observable
final class ZoomModel {
    /// Current zoom factor as shown on the lens buttons.
    private(set) var factor: CGFloat = 1
    /// Whether the zoom dial is open.
    private(set) var isDialOpen = false
    /// Lenses and zoom range of the running camera, nil until one has started.
    private(set) var capabilities: CameraCapabilities?

    @ObservationIgnored private let service: any CameraService
    @ObservationIgnored private let haptics: any CameraHaptics
    /// Decides the dial ticks while the dial turns, nil while it is closed.
    @ObservationIgnored private var dialTicks: DialHaptics?
    /// True while a camera starts, until it has started: a zoom asked for meanwhile would reach the camera that
    /// starts and not show on the lens buttons, so it is dropped.
    @ObservationIgnored private var isCameraStarting = false
    /// Hears the zoom cross into another lens, whatever moved it.
    @ObservationIgnored var onLensChange: () -> Void = {}

    /// Doublings per second of the zoom ramp after a lens button tap.
    private static let lensRampRate: Float = 8

    init(service: any CameraService, haptics: any CameraHaptics) {
        self.service = service
        self.haptics = haptics
    }

    // MARK: - The running camera

    var lenses: [CameraLens] {
        capabilities?.lenses ?? []
    }

    var scale: ZoomScale {
        ZoomScale(range: capabilities?.zoomRange ?? 1...1)
    }

    /// Extra factors the dial marks with a dot.
    var markedFactors: [CGFloat] {
        capabilities?.markedFactors ?? []
    }

    /// The lens button that shows the current zoom: the nearest lens at or below it.
    var activeLensIndex: Int? {
        lensIndex(atZoom: factor)
    }

    /// Factors written on the dial: every lens and the end of the range.
    var dialLabelFactors: [CGFloat] {
        guard let capabilities else { return [] }
        let factors = capabilities.lenses.map(\.factor)
        let upperBound = capabilities.zoomRange.upperBound
        return factors.contains(upperBound) ? factors : factors + [upperBound]
    }

    /// Factors the dial holds on to while it turns.
    var dialSnapFactors: [CGFloat] {
        Array(dialLabelFactors.dropFirst().dropLast())
    }

    // MARK: - Zooming

    /// A camera is about to start: the zoom holds still until one has started.
    func cameraStarting() {
        isCameraStarting = true
    }

    /// A camera that has just started is on its main lens.
    func cameraStarted(_ capabilities: CameraCapabilities) {
        self.capabilities = capabilities
        isCameraStarting = false
        setFactor(1)
    }

    /// Switches to a lens with a short zoom ramp.
    func selectLens(at index: Int) {
        guard !isCameraStarting, lenses.indices.contains(index) else { return }
        setFactor(lenses[index].factor)
        service.rampZoom(to: factor, rate: Self.lensRampRate)
    }

    /// Sets the zoom at once.
    func setZoom(_ factor: CGFloat) {
        guard !isCameraStarting else { return }
        setFactor(scale.clamped(factor))
        service.setZoom(self.factor)
    }

    /// Sets the zoom from the turning dial, which ticks on every lens factor and on every whole factor between
    /// the two longest lenses, as the stock dial does.
    func turnDial(to factor: CGFloat) {
        var ticks = dialTicks ?? freshDialTicks
        setZoom(factor)
        if ticks.update(zoom: self.factor) {
            haptics.play(.dialTick)
        }
        dialTicks = ticks
    }

    /// Takes a zoom the Camera Control already applied to the camera. A zoom beyond the dial's range is replaced by
    /// the nearest end of it, which goes back to the camera.
    func factorChanged(to factor: CGFloat) {
        let kept = scale.clamped(factor)
        setFactor(kept)
        if kept != factor {
            service.setZoom(kept)
        }
    }

    func openDial() {
        isDialOpen = true
    }

    func closeDial() {
        isDialOpen = false
        dialTicks = nil
    }

    // MARK: - Private

    /// The nearest lens at or below a zoom factor.
    private func lensIndex(atZoom factor: CGFloat) -> Int? {
        guard !lenses.isEmpty else { return nil }
        return lenses.lastIndex { $0.factor <= factor + 0.001 } ?? 0
    }

    /// Changes the factor. When the zoom crosses into another lens, it moves the Camera Control's lens picker and
    /// reports the change.
    private func setFactor(_ newFactor: CGFloat) {
        let previousIndex = lensIndex(atZoom: factor)
        factor = newFactor
        guard let index = activeLensIndex, index != previousIndex else { return }
        service.selectCaptureControlLens(at: index)
        onLensChange()
    }

    /// The dial's tick zones started at the current zoom, so the first tick comes at the next significant factor:
    /// every lens and every whole factor between the two longest lenses.
    private var freshDialTicks: DialHaptics {
        var ticks = DialHaptics(
            labeledFactors: lenses.map(\.factor),
            snapFactors: dialSnapFactors,
            scale: scale,
            radius: CameraMetrics.ZoomDial.radius
        )
        _ = ticks.update(zoom: factor)
        return ticks
    }
}
