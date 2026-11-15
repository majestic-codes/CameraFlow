//
//  CaptureSessionCore+Capture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

// MARK: - A photo of the single camera or of the pair

extension CaptureSessionCore {

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let finish = self.capturesInFlight.begin { continuation.resume(with: $0) }
                if let dual = self.dual {
                    self.captureDualPhoto(request, with: dual, completion: finish)
                    return
                }
                guard self.session.isRunning else {
                    finish(.failure(CameraServiceError.notRunning))
                    return
                }
                let built: CapturePhotoSettingsBuilder.Built
                do {
                    built = try CapturePhotoSettingsBuilder.settings(for: request, output: self.photoOutput)
                } catch {
                    finish(.failure(error))
                    return
                }
                self.applyCaptureRotation()
                self.capture(built, location: request.location, with: self.photoOutput, completion: finish)
            }
        }
    }

    /// Rotates the photo to the way the phone is held, not the way the interface is. The angle is the running
    /// camera's own: the same hold gives another angle on a sensor that is mounted another way.
    private func applyCaptureRotation() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let rotationCoordinator, let connection = photoOutput.connection(with: .video) else {
            Self.logger.error("The photo keeps the turn of the sensor: the camera has no photo connection to turn")
            return
        }
        CaptureRotation.rotate(connection, to: rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
    }

    /// Fires the camera of the viewfinder and the camera of the circle at once, each turned level with the horizon
    /// by its own coordinator, and hands both photos over together.
    private func captureDualPhoto(
        _ request: PhotoCaptureRequest,
        with dual: CaptureDualSession,
        completion: @escaping @Sendable (Result<CapturedPhoto, any Error>) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard dual.session.isRunning else {
            completion(.failure(CameraServiceError.notRunning))
            return
        }
        let main = dual.main
        let circle = dual.circle
        let built: CapturePhotoSettingsBuilder.Built
        do {
            built = try CapturePhotoSettingsBuilder.settings(for: request, output: main.photoOutput)
        } catch {
            completion(.failure(error))
            return
        }
        for camera in [main, circle] {
            camera.levelCaptures()
        }
        let shot = CaptureDualShot(
            queue: queue,
            viewfinderQuarterTurns: dual.viewfinderQuarterTurns,
            isViewfinderMirrored: main.position.isMirroredOnScreen,
            completion: completion
        )
        capture(built, location: request.location, with: main.photoOutput) { result in
            self.queue.async { shot.mainFinished(result) }
        }
        let circleSettings = CaptureDualShot.circleSettings(for: circle.photoOutput, of: circle.device)
        capture(circleSettings, location: nil, with: circle.photoOutput) { result in
            self.queue.async { shot.circleFinished(result) }
        }
    }
}
#endif
