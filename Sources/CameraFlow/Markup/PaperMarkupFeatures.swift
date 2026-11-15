//
//  PaperMarkupFeatures.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import PaperKit

/// What the PaperKit canvas offers.
@available(iOS 26, macOS 26, *)
enum PaperMarkupFeatures {
    /// The first version of PaperKit's features, so that a later system adds nothing the review and the copy were
    /// not checked with, without the loupe and the link. PaperKit shows both on its live canvas only: a stored
    /// drawing renders without them, so the review and the copy would not have them.
    static let supported: FeatureSet = {
        var features = FeatureSet.version1
        features.remove(.loupes)
        features.remove(.links)
        return features
    }()
}
