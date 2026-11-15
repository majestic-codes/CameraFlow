//
//  CameraTextStyle+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import SwiftUI

extension CameraTextStyle {
    /// The letter spacing of the stock badges, in thousandths of their size.
    private static let badgeTrackingPerMille: CGFloat = 25

    /// The AE/AF LOCK badge at the default text size.
    static let focusLockBadge = focusLockBadge(size: focusLockBadgeSize(at: .large))

    /// The AE/AF LOCK badge at a size: the medium weight narrowed to the stock digit width, fitted to the stock badges
    /// of iOS 27, with the stock letters 0.025 em apart.
    static func focusLockBadge(size: CGFloat) -> Self {
        let tracking = size * badgeTrackingPerMille / 1000
        return Self(size: size, weight: Weight.medium, widthAxis: valueWidthAxis, tracking: tracking)
    }

    /// The size of the badge at a text size, in the stock badge's steps on a phone: 14 pt up to Large, 15 pt at
    /// Extra Large, 17 pt at Extra Extra Large, and 19 pt from Extra Extra Extra Large on.
    static func focusLockBadgeSize(at textSize: DynamicTypeSize) -> CGFloat {
        if textSize <= .large {
            return 14
        }
        if textSize == .xLarge {
            return 15
        }
        return textSize == .xxLarge ? 17 : 19
    }
}
