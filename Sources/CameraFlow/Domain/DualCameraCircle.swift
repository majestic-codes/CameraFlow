//
//  DualCameraCircle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The circle of the second camera as the viewfinder shows it, in terms that hold for a photo of any size.
struct DualCameraCircle: Sendable, Equatable {
    /// The square that holds the circle, in unit coordinates of the viewfinder with the origin at the top left.
    let region: CGRect
    /// The width of the white rim, as a share of the diameter of the circle.
    let rimWidthRatio: CGFloat
    let rimOpacity: Double
    /// The blur of the shadow under the circle, as a share of its diameter.
    let shadowRadiusRatio: CGFloat
    let shadowOpacity: Double
}
