//
//  CameraScreenLayout+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where the AE/AF LOCK badge goes: its centre, its length along its line and its turn.
struct FocusLockBadgePlacement: Equatable {
    let center: CGPoint
    /// The badge's own length, or the room along its tray where that is shorter: the text is then set smaller.
    let length: CGFloat
    /// Clockwise degrees, the turn of the elements that stay upright.
    let angle: Double
}

/// The stock badge tray and the AE/AF LOCK badge in it. The tray lies across the top of the viewfinder and, while
/// the phone is held in landscape, along the edge of the viewfinder that is up for the user.
extension CameraScreenLayout {
    /// The stock badge tray across the top of the viewfinder, below the line of the top bar where a 16:9 viewfinder
    /// reaches up beside it.
    var badgeTray: CGRect {
        let frame = viewfinder
        let top = max(frame.minY, topLineBottom)
        return CGRect(x: frame.minX, y: top, width: frame.width, height: CameraMetrics.FocusLockBadge.trayHeight)
    }

    /// The badge of a length, upright for the user and in the middle of its tray: at the top of the viewfinder, or
    /// at its trailing or leading edge while the phone is held in landscape. It keeps clear of the ends of the tray
    /// and of the second camera's circle, moving off the middle where it would reach them.
    func focusLockBadge(
        length: CGFloat,
        isDualCameraCircleShown: Bool,
        elementOrientation: CameraOrientation
    ) -> FocusLockBadgePlacement {
        let inset = CameraMetrics.FocusLockBadge.edgeInset
        let halfTray = CameraMetrics.FocusLockBadge.trayHeight / 2
        let frame = viewfinder
        let tray = badgeTray
        let circle = dualCameraCircle
        let angle = elementOrientation.elementAngle
        switch elementOrientation {
        case .portrait, .upsideDown:
            let end = isDualCameraCircleShown ? min(tray.maxX, circle.minX) : tray.maxX
            let line = Self.place(length, from: tray.minX + inset, to: end - inset, around: tray.midX)
            let center = CGPoint(x: line.middle, y: tray.midY)
            return FocusLockBadgePlacement(center: center, length: line.length, angle: angle)
        case .landscapeLeft:
            let start = isDualCameraCircleShown ? max(tray.minY, circle.maxY) : tray.minY
            let line = Self.place(length, from: start + inset, to: frame.maxY - inset, around: frame.midY)
            let center = CGPoint(x: frame.maxX - halfTray, y: line.middle)
            return FocusLockBadgePlacement(center: center, length: line.length, angle: angle)
        case .landscapeRight:
            let line = Self.place(length, from: tray.minY + inset, to: frame.maxY - inset, around: frame.midY)
            let center = CGPoint(x: frame.minX + halfTray, y: line.middle)
            return FocusLockBadgePlacement(center: center, length: line.length, angle: angle)
        }
    }

    /// The row of the notice capsule, which moves below the badge tray while the badge shows at the top of the
    /// viewfinder.
    func notice(
        isDualCameraCircleShown: Bool,
        isFocusLockBadgeShown: Bool,
        elementOrientation: CameraOrientation
    ) -> CGRect {
        let row = notice(isDualCameraCircleShown: isDualCameraCircleShown)
        let isBadgeAtTop = switch elementOrientation {
        case .portrait, .upsideDown: true
        case .landscapeLeft, .landscapeRight: false
        }
        guard isFocusLockBadgeShown, isBadgeAtTop else { return row }
        return CGRect(x: row.minX, y: max(row.minY, badgeTray.maxY), width: row.width, height: row.height)
    }

    /// A length on a line between two ends, as near its preferred middle as the ends let it, and no longer than the
    /// room between them.
    private static func place(
        _ length: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        around preferred: CGFloat
    ) -> (middle: CGFloat, length: CGFloat) {
        let fitted = max(min(length, end - start), 0)
        let lowest = start + fitted / 2
        let highest = max(end - fitted / 2, lowest)
        return (min(max(preferred, lowest), highest), fitted)
    }
}
