//
//  CaptureFlashWatch.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// The flash of the camera in the viewfinder of `CaptureSessionCore`: its photo output monitors the scene for the
/// flash mode the flow chose, as the next photo in the flow's format would be taken, and the watch follows that scene
/// and whether the device's flash can fire. Read and written on the queue of the core only.
final class CaptureFlashWatch {
    /// The flash of the watched camera as it was reported.
    private struct Report {
        let isFlashScene: Bool
        let availability: FlashAvailability
    }

    /// What the flow monitors the scene for: the flash mode, and the format of the next photo.
    private struct Monitoring {
        let flashMode: CameraFlowFlashMode
        let format: CameraFlowPhotoFormat
    }

    private let queue: DispatchQueue
    /// What the flow monitors the scene for, nil until it says. Every output the watch moves to takes it.
    private var monitoring: Monitoring?
    private var device: AVCaptureDevice?
    private var output: AVCapturePhotoOutput?
    private var observations: [NSKeyValueObservation] = []
    /// What was reported last, so that only a change is reported again.
    private var reported: Report?

    /// - Parameter queue: The queue of `CaptureSessionCore`.
    init(queue: DispatchQueue) {
        self.queue = queue
    }

    /// Monitors the scene of the watched camera for the flash in this mode, as the next photo in the format would be
    /// taken, and the scene of every camera watched later.
    func monitor(_ flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {
        dispatchPrecondition(condition: .onQueue(queue))
        monitoring = Monitoring(flashMode: flashMode, format: format)
        if let output {
            monitorScene(of: output)
        }
    }

    /// Moves to the flash of the camera that came into the viewfinder, and calls `onChange` from any thread whenever
    /// its scene or whether it can fire may have changed, the first time at once.
    func watch(_ device: AVCaptureDevice, output: AVCapturePhotoOutput, onChange: @escaping @Sendable () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))
        stop()
        self.device = device
        self.output = output
        monitorScene(of: output)
        observations = [
            output.observe(\.isFlashScene, options: [.initial, .new]) { _, _ in onChange() },
            device.observe(\.isFlashAvailable, options: [.new]) { _, _ in onChange() },
            device.observe(\.systemPressureState, options: [.new]) { _, _ in onChange() }
        ]
    }

    /// Lets the watched camera go: its output no longer monitors the scene.
    func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        observations.forEach { $0.invalidate() }
        observations = []
        output?.photoSettingsForSceneMonitoring = nil
        output = nil
        device = nil
    }

    /// The events of what changed in the flash of the watched camera since the last call: its scene first, then
    /// whether it can fire. None while no camera is watched.
    func changes() -> [CameraSessionEvent] {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let device, let output else { return [] }
        let report = Report(
            isFlashScene: output.isFlashScene,
            availability: CaptureDeviceInspector.flashAvailability(of: device)
        )
        defer { reported = report }
        var events: [CameraSessionEvent] = []
        if report.isFlashScene != reported?.isFlashScene {
            events.append(.flashSceneChanged(report.isFlashScene))
        }
        if report.availability != reported?.availability {
            events.append(.flashAvailabilityChanged(report.availability))
        }
        return events
    }

    private func monitorScene(of output: AVCapturePhotoOutput) {
        output.photoSettingsForSceneMonitoring = monitoring.map { monitoring in
            CapturePhotoSettingsBuilder.sceneMonitoringSettings(
                for: monitoring.flashMode,
                format: monitoring.format,
                output: output
            )
        }
    }
}
#endif
