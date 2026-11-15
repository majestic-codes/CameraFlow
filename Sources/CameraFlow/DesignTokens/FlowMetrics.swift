//
//  FlowMetrics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Sizes of the flow's own controls in points, from the approved mock-up of a 402 x 874 screen.
enum FlowMetrics {
    /// The capsule with the two modes in the slot of the stock mode picker.
    enum ModeSwitch {
        /// Space between the edge of the capsule and the pill of the selected mode.
        static let segmentInset: CGFloat = 4
        static let badgeDiameter: CGFloat = 20
        /// Where the centre of the badge sits from the top trailing corner of the capsule, inwards and down.
        static let badgeCenterInset = CGSize(width: 10, height: 6)
        static let selectedRimWidth: CGFloat = 1
        /// The most the thumb gives way beyond an end of its travel, however far the finger goes. Our own.
        static let rubberBandLimit: CGFloat = 12
        /// How soon the thumb reaches that limit: the higher, the more it follows the finger. Our own.
        static let rubberBandStiffness: CGFloat = 0.55
        /// How far ahead, in seconds, the thumb is projected at the release to decide where it settles. Our own.
        static let projectionTime: CGFloat = 0.12
        /// The distance a finger may move and still tap.
        static let tapSlop: CGFloat = 6
        /// How much the thumb stretches along its way at most, and the finger speed in points per second that
        /// stretches it so far. Our own.
        static let stretchLimit: CGFloat = 0.04
        static let stretchSpeed: CGFloat = 1200
        /// A thumb closer to its target than this share of the travel settles without the speed of the finger,
        /// and the speed never counts for more than this many travels per second.
        static let minimumSettleDistance: CGFloat = 0.02
        static let settleVelocityLimit: Double = 8
        /// The smallest share of its size a label is set at where its pill is too narrow for it, as in a 320 pt
        /// window.
        static let labelMinimumScale: CGFloat = 0.6
    }

    /// A round button in a top corner of the screen, on the line of the top bar.
    enum CornerButton {
        static let diameter: CGFloat = 44
        static let sideInset: CGFloat = 16
    }

    /// The pages of the review.
    enum ReviewPager {
        /// Black space between two photos while one page gives way to the next. Our own, not in the mock-up.
        static let pageGap: CGFloat = 20
    }

    /// A photo of the review under a pinch and a double tap. Our own, not in the mock-up.
    enum PhotoZoom {
        static let maximumScale: CGFloat = 4
        /// The scale a double tap zooms a fitted photo to.
        static let doubleTapScale: CGFloat = 2.5
    }

    /// The pen tip of the system Markup, set as a symbol of these point sizes. Our own, fitted by eye.
    enum MarkupSymbol {
        /// In the corner button, where it weighs what the trash opposite does.
        static let buttonPointSize: CGFloat = 22
        /// On the dot of a photo with a drawing.
        static let drawingMarkPointSize: CGFloat = 9.5
    }

    /// The top bar of the drawing mode: a capsule with a label in each corner, on the line and of the height of
    /// the corner buttons, and the round undo and redo buttons between them.
    enum MarkupTopBar {
        static let stepButtonDiameter: CGFloat = 40
        /// The circle undo and redo take a touch in: the 44 points a finger needs, around the drawn button.
        static let stepButtonTouchDiameter: CGFloat = 44
        /// Space between a label and each end of its capsule, as the mock-up leaves it beside the Ukrainian "Cancel"
        /// label.
        static let labelPadding: CGFloat = 15
        /// The least width of a capsule, which the mock-up gives the Ukrainian "Done" label.
        static let minimumCapsuleWidth: CGFloat = 90
        /// The least space between a capsule and the round button next to it. Our own, not in the mock-up.
        static let stepButtonGap: CGFloat = 8
        /// The smallest share of its size a label is set at where its capsule is too narrow for it.
        static let labelMinimumScale: CGFloat = 0.7
    }

    /// The strip of the set in the review: round tiles of the size of the buttons beside the shutter, on their
    /// line.
    enum Strip {
        /// From one tile to the next.
        static let pitch: CGFloat = 56
        /// The ring around the tile of the current photo, measured along the middle of its line.
        static let currentRingDiameter: CGFloat = 53
        static let currentRingWidth: CGFloat = 2.5
        static let rimWidth: CGFloat = 1
        /// The dot on a photo with a drawing: its centre from the origin of the tile, and its outline.
        static let drawingMarkCenter = CGPoint(x: 41, y: 41)
        static let drawingMarkDiameter: CGFloat = 16
        static let drawingMarkOutlineWidth: CGFloat = 1.5
    }

    /// The second camera's circle in the top trailing corner of the viewfinder. Its sizes are the package's own, not
    /// measured on a stock screen.
    enum DualCameraCircle {
        /// The diameter as a share of the width of the viewfinder: 133 pt on a 402 pt screen.
        static let diameterPerViewfinderWidth: CGFloat = 0.33
        /// Space from the circle to the trailing edge of the viewfinder, to its top and to the flip button.
        static let margin: CGFloat = 12
        static let rimWidth: CGFloat = 1.5
        static let rimOpacity = 0.85
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity = 0.35
    }

    /// The glyph of the second camera's circle: the rounded square of the `app` symbol with a dot in its top
    /// trailing corner. The sizes are for the symbol at `CameraMetrics.Symbol.topBarPointSize`, fitted by eye against
    /// the Flash and Live glyphs; the tile and the sub-panel scale them to their point size.
    enum DualCameraToggle {
        static let dotDiameter: CGFloat = 5.5
        /// How far the centre of the dot sits from the centre of the frame, to the trailing side and up.
        static let dotOffset: CGFloat = 2.6
    }

    /// The small copy of a fresh photo that flies into the review segment. Only its landing place is in the
    /// mock-up; the sizes are our own.
    enum CaptureFlight {
        /// The square the copy fits into as it takes off from the middle of the viewfinder.
        static let startSide: CGFloat = 132
        static let cornerRadius: CGFloat = 10
        /// The scale the copy has shrunk to when it lands.
        static let landingScale: CGFloat = 0.12
        static let landingOpacity = 0.3
    }
}
