//
//  FlowMotion.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Animations of the flow's own controls. None of them is measured on the stock camera.
enum FlowMotion {
    /// The two contents of the flow changing places.
    static let modeChange = Animation.spring(response: 0.35, dampingFraction: 0.86)
    /// The thumb of the mode switch settling on a segment: a little life, no visible wobble (about 1.5 % over).
    static let modeThumbSpring = Spring(response: 0.34, dampingRatio: 0.8)
    /// The thumb settling, starting at the speed of the finger that let it go. The velocity is in distances to
    /// the target per second.
    static func modeThumbSettle(initialVelocity: Double) -> Animation {
        .interpolatingSpring(modeThumbSpring, initialVelocity: initialVelocity)
    }
    /// The thumb settling for people who reduce motion.
    static let modeThumbSettleReduced = Animation.easeOut(duration: 0.15)
    /// The thumb stretching and relaxing with the speed of the finger.
    static let modeThumbStretch = Animation.easeOut(duration: 0.12)
    /// A control of the bottom bar turning active or inactive, and the badge and the spinner coming and going.
    static let availability = Animation.easeOut(duration: 0.2)
    /// The small copy of a fresh photo on its way into the review segment.
    static let captureFlight = Animation.timingCurve(0.5, 0, 0.75, 0.6, duration: 0.42)
    /// The badge taking the landed copy in.
    static let badgeBump = Animation.spring(response: 0.3, dampingFraction: 0.5)
    static let badgeBumpScale: CGFloat = 1.3
    /// The drawing mode taking the place of the bars of the review and of the bottom bar, and giving it back.
    static let markupChange = Animation.easeInOut(duration: 0.25)
    /// The strip moving the tile of the current photo into its middle.
    static let stripFollow = Animation.easeInOut(duration: 0.25)
    /// The second camera's circle growing in from its corner and shrinking back into it.
    static let dualCameraCircle = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let dualCameraCircleHiddenScale: CGFloat = 0.6
}
#endif
