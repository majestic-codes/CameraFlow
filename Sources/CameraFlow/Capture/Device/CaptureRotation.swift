//
//  CaptureRotation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
// The observation of a rotation coordinator carries an AVCaptureConnection, which is not Sendable, to the queue that
// owns it.
@preconcurrency import AVFoundation
import os

/// Turns the picture of a capture connection: a photo level with the horizon, a preview level with its interface.
enum CaptureRotation {
    private static let logger = Logger.camera("CaptureRotation")

    /// Turns a connection to an angle. A connection that cannot take the angle keeps the one it had, and the log
    /// says so.
    static func rotate(_ connection: AVCaptureConnection, to angle: CGFloat) {
        guard connection.isVideoRotationAngleSupported(angle) else {
            logger.error("A capture connection cannot turn to \(angle, privacy: .public) degrees")
            return
        }
        connection.videoRotationAngle = angle
    }
}

/// A preview connection kept level with the interface its layer is shown in, by a rotation coordinator of the camera
/// and the layer, for as long as it lives. The coordinator reports on the main queue, and the connection is turned on
/// the queue of `CaptureSessionCore`.
final class PreviewLevel {
    private let coordinator: AVCaptureDevice.RotationCoordinator
    private let observation: NSKeyValueObservation

    /// Turns the connection level now and whenever the interface turns.
    init(
        _ connection: AVCaptureConnection,
        of layer: AVCaptureVideoPreviewLayer,
        device: AVCaptureDevice,
        queue: DispatchQueue
    ) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        CaptureRotation.rotate(connection, to: coordinator.videoRotationAngleForHorizonLevelPreview)
        let keyPath = \AVCaptureDevice.RotationCoordinator.videoRotationAngleForHorizonLevelPreview
        observation = coordinator.observe(keyPath, options: [.new]) { coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            queue.async {
                CaptureRotation.rotate(connection, to: angle)
            }
        }
        self.coordinator = coordinator
    }

    deinit {
        observation.invalidate()
    }
}
#endif
