//
//  ModeSwitchLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The widths of the two labels of the mode switch as they are set, which depend on the language.
struct ModeLabelWidths: Equatable, Sendable {
    let shooting: CGFloat
    let review: CGFloat
}

/// Frames of the parts of the mode switch, in the coordinates of the whole screen.
struct ModeSwitchLayout: Equatable, Sendable {
    /// The capsule.
    let frame: CGRect
    let labelWidths: ModeLabelWidths

    /// The pill of a mode. The two pills fill the capsule side by side, each as wide as its label and half of
    /// the space the labels leave, so both labels get the same margins in every language.
    func segment(_ mode: CameraFlowMode) -> CGRect {
        let inset = FlowMetrics.ModeSwitch.segmentInset
        let pills = frame.insetBy(dx: inset, dy: inset)
        let preferredWidth = (pills.width + labelWidths.shooting - labelWidths.review) / 2
        let shootingWidth = min(max(preferredWidth, 0), pills.width)
        switch mode {
        case .shooting:
            return CGRect(x: pills.minX, y: pills.minY, width: shootingWidth, height: pills.height)
        case .review:
            let width = pills.width - shootingWidth
            return CGRect(x: pills.minX + shootingWidth, y: pills.minY, width: width, height: pills.height)
        }
    }

    /// The same layout with the capsule at the origin, for views that draw inside the capsule.
    var insideCapsule: Self {
        Self(frame: CGRect(origin: .zero, size: frame.size), labelWidths: labelWidths)
    }

    /// The distance the thumb travels from the first mode to the second.
    var travel: CGFloat {
        segment(.review).minX - segment(.shooting).minX
    }

    /// The thumb when it is `progress` of the way from the first mode to the second, 0 for the shooting and 1 for
    /// the review. Its position and its width change together, so it fits each pill at its end.
    func thumb(at progress: CGFloat) -> CGRect {
        let first = segment(.shooting)
        let second = segment(.review)
        return CGRect(
            x: first.minX + (second.minX - first.minX) * progress,
            y: first.minY,
            width: first.width + (second.width - first.width) * progress,
            height: first.height
        )
    }

    /// The mode whose pill holds a place across the capsule.
    func mode(atOffset offset: CGFloat) -> CameraFlowMode {
        offset < segment(.review).minX ? .shooting : .review
    }

    /// The count of the set, a circle over the top trailing corner of the capsule.
    var badge: CGRect {
        let inset = FlowMetrics.ModeSwitch.badgeCenterInset
        let center = CGPoint(x: frame.maxX - inset.width, y: frame.minY + inset.height)
        return CameraScreenLayout.square(FlowMetrics.ModeSwitch.badgeDiameter, center: center)
    }
}
