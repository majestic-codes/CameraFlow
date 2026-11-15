//
//  PhotoSettingsModel+DualCamera.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the next photo is taken with: the chosen settings as the running camera and the flow's rules leave them.
struct PhotoSettingsInEffect: Sendable, Equatable {
    let isLivePhotoOn: Bool
    let format: CameraFlowPhotoFormat
    let resolution: PhotoCaptureResolution
    let flashMode: CameraFlowFlashMode
}

// MARK: - In the dual camera

extension PhotoSettingsModel {
    /// What the next photo is taken with now as the running camera offers it, nil until the camera has started and
    /// offers a size.
    var inEffect: PhotoSettingsInEffect? {
        guard let effectivePhotoFrame else { return nil }
        return PhotoSettingsInEffect(
            isLivePhotoOn: isLivePhotoInEffect,
            format: effectivePhotoFormat,
            resolution: effectivePhotoFrame,
            flashMode: effectiveFlashMode
        )
    }

    /// The first setting in effect before the circle came on that the pair leaves out, nil when it keeps them all.
    func dualCameraNarrowedSetting(comparedTo before: PhotoSettingsInEffect) -> DualCameraSetting? {
        guard let now = inEffect else { return nil }
        if before.isLivePhotoOn, !now.isLivePhotoOn {
            return .livePhoto
        }
        if before.format == .raw, now.format != .raw {
            return .raw
        }
        if before.resolution.isPreferred, now.resolution.megapixels < PhotoCaptureResolution.preferredMegapixels {
            return .resolution
        }
        if before.flashMode != now.flashMode {
            return .flash
        }
        return nil
    }
}
