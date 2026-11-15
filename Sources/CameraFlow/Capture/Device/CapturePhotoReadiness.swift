//
//  CapturePhotoReadiness.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

/// The readiness of one photo output to take another photo, through a readiness coordinator of its own. The
/// coordinator calls on the main queue and is made to be used beside an output on another queue, and `latest` is read
/// and written on the queue of `CaptureSessionCore` only, which is what makes the unchecked sendability hold.
final class CapturePhotoReadiness: NSObject, AVCapturePhotoOutputReadinessCoordinatorDelegate, @unchecked Sendable {
    let output: AVCapturePhotoOutput
    /// What the coordinator reported last, nil before its first report.
    var latest: CaptureReadiness?
    private let coordinator: AVCapturePhotoOutputReadinessCoordinator
    private let onChange: @Sendable (CapturePhotoReadiness, CaptureReadiness) -> Void

    private static let logger = Logger.camera("CapturePhotoReadiness")

    /// - Parameter onChange: Takes each change of the readiness on the main queue, the readiness the output has now
    ///   first.
    init(
        output: AVCapturePhotoOutput,
        onChange: @escaping @Sendable (CapturePhotoReadiness, CaptureReadiness) -> Void
    ) {
        self.output = output
        coordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: output)
        self.onChange = onChange
        super.init()
        coordinator.delegate = self
    }

    /// Counts a request in the readiness until the output takes it in, which the capture that follows does at once.
    func track(_ settings: AVCapturePhotoSettings) {
        coordinator.startTrackingCaptureRequest(using: settings)
    }

    func readinessCoordinator(
        _ coordinator: AVCapturePhotoOutputReadinessCoordinator,
        captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness
    ) {
        onChange(self, Self.readiness(of: captureReadiness))
    }

    /// The readiness as the camera service speaks of it. One that this code does not know is logged and taken for a
    /// moment's wait, so the shutter waits for the next report.
    private static func readiness(of captureReadiness: AVCapturePhotoOutput.CaptureReadiness) -> CaptureReadiness {
        switch captureReadiness {
        case .sessionNotRunning:
            return .notRunning
        case .ready:
            return .ready
        case .notReadyMomentarily:
            return .notReadyMomentarily
        case .notReadyWaitingForCapture:
            return .waitingForCapture
        case .notReadyWaitingForProcessing:
            return .waitingForProcessing
        @unknown default:
            logger.error("Unknown capture readiness \(captureReadiness.rawValue, privacy: .public) taken for a wait")
            return .notReadyMomentarily
        }
    }
}
#endif
