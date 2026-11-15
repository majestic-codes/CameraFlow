//
//  CameraMetrics+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

extension CameraMetrics {
    /// The reticle of the AE/AF Lock, read from the stock camera's code.
    enum FocusLock {
        /// The square of a long press, larger than a tap's while the finger holds. The stock styles are 125 pt and
        /// 75 pt squares in the simulator, with lines and ticks of the same width.
        static let pressedReticleScale: CGFloat = 125.0 / 75.0
        /// How far the square grows on each side as the lock takes, before it settles back.
        static let lockBounceExpansion: CGFloat = 31
    }

    /// The stock AE/AF LOCK badge in the badge tray at the top of the viewfinder, measured on the badges of iOS 27.
    enum FocusLockBadge {
        /// The height of the stock badge tray. The badge sits in its middle.
        static let trayHeight: CGFloat = 40
        /// The space above and below the text, which makes the badge 24 pt high at its default size.
        static let verticalPadding: CGFloat = 3.75
        /// The space before and after the text: 7.75 pt on the other stock badges, and the lock badge adds a point.
        static let textInset: CGFloat = 8.75
        static let cornerRadius: CGFloat = 5
        /// The least space between the badge and the ends of its tray, or the second camera's circle.
        static let edgeInset: CGFloat = 8
        /// The smallest share of its size the text is set at where the badge is too long for its tray, small enough
        /// for the longest translation at the largest text size beside the second camera's circle in the narrowest
        /// window.
        static let minimumTextScale: CGFloat = 0.5
        /// How dark the text cut out of the plate is: black at 60 %, through which the picture shows.
        static let textOpacity = 0.6
    }
}
