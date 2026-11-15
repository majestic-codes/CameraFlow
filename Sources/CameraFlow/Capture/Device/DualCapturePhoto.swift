//
//  DualCapturePhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os

/// The photo of a dual capture, from the photos of its two cameras.
enum DualCapturePhoto {
    private static let logger = Logger.camera("DualCapturePhoto")

    /// The main photo with the frame of the circle, or the main photo alone, marked as without its circle, when only
    /// the circle's photo failed. A failed main photo fails the capture.
    static func combining(
        main: Result<CapturedPhoto, any Error>,
        circle: Result<CapturedPhoto, any Error>,
        isViewfinderMirrored: Bool,
        viewfinderQuarterTurns: Int
    ) -> Result<CapturedPhoto, any Error> {
        switch (main, circle) {
        case let (.success(photo), .success(circlePhoto)):
            var combined = photo
            combined.circleCameraFrame = CircleCameraFrame(
                imageData: circlePhoto.imageData,
                isViewfinderMirrored: isViewfinderMirrored,
                viewfinderQuarterTurns: viewfinderQuarterTurns
            )
            return .success(combined)
        case let (.success(photo), .failure(error)):
            let reason = String(describing: error)
            logger.error("The photo goes without the circle, whose frame failed: \(reason, privacy: .public)")
            var alone = photo
            alone.losses.append(.circleCameraFrame)
            return .success(alone)
        case let (.failure(error), _):
            return .failure(error)
        }
    }
}
