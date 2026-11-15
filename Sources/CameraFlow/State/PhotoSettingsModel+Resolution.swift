//
//  PhotoSettingsModel+Resolution.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The size of the photo

extension PhotoSettingsModel {
    /// The size a capture uses, nil until the camera has started: 12 MP where the camera has it, its largest size
    /// otherwise. A size above the output's is scaled down afterwards.
    var effectivePhotoFrame: PhotoCaptureResolution? {
        photoCapabilities?.resolution
    }

    /// Whether the running camera's photos fit the size of an output as they are.
    func deliversPhotos(within output: CameraFlowOutput) -> Bool {
        guard let effectivePhotoFrame else { return false }
        return Int(effectivePhotoFrame.width) <= output.size.maximumLongSide ?? .max
    }
}
