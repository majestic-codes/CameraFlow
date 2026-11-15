//
//  ReviewTopBarLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of the top bar of the review, in the coordinates of the whole screen: the trash and the Markup button in
/// the top corners and the counter between them. In a right-to-left language the bar is the mirror image, the trash
/// in the right corner, as the system's own controls are.
struct ReviewTopBarLayout: Equatable, Sendable {
    let screen: CameraScreenLayout
    let isRightToLeft: Bool

    var trash: CGRect {
        isRightToLeft ? screen.reviewMarkup : screen.reviewTrash
    }

    var markup: CGRect {
        isRightToLeft ? screen.reviewTrash : screen.reviewMarkup
    }

    /// The counter, centred between the corner buttons in either direction.
    var counter: CGRect {
        screen.reviewCounter
    }
}
