//
//  PhotoSettingsModel+Quality.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The quality of the photos and what its output leaves

extension PhotoSettingsModel {
    /// The output of the next photo: the app's, narrowed by the quality the user picked.
    var output: CameraFlowOutput {
        quality.output
    }

    /// The qualities the Format panel shows, best first: none while the app fixed the quality or its output leaves
    /// nothing to choose.
    var offeredPhotoQualities: [CameraFlowQuality] {
        quality.offered
    }

    /// The quality of the next photo.
    var photoQuality: CameraFlowQuality {
        quality.quality
    }
}
