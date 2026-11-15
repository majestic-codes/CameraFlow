//
//  CameraScreenLayout+Flow.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of the flow's own elements that stand outside the bottom bar. The review has its own in
/// `CameraScreenLayout+Review`.
extension CameraScreenLayout {
    /// The camera flip in the top trailing corner.
    var flip: CGRect {
        cornerButton(isTrailing: true)
    }

    /// A round button in a top corner of the column, on the line of the top bar.
    func cornerButton(isTrailing: Bool) -> CGRect {
        let diameter = FlowMetrics.CornerButton.diameter
        let inset = FlowMetrics.CornerButton.sideInset + diameter / 2
        let centerY = topBarButton(at: 0, of: 1).midY
        let frame = column
        let centerX = isTrailing ? frame.maxX - inset : frame.minX + inset
        return Self.square(diameter, center: CGPoint(x: centerX, y: centerY))
    }

    /// The strip the top bar lives in: centred on the screen, from the leading slot to a slot's gap before the flip
    /// button, so a row that fits keeps its centred place and a row that does not scrolls inside it.
    var topBarViewport: CGRect {
        let side = CameraMetrics.TopBar.buttonSize
        let gap = CameraMetrics.TopBar.pitch - side
        let middle = column.midX
        let halfWidth = max(flip.minX - gap - middle, side / 2)
        let slot = topBarButton(at: 0, of: 1)
        return CGRect(x: middle - halfWidth, y: slot.minY, width: halfWidth * 2, height: side)
    }

    /// The strip of the top bar grown on every side to the squares its items take a touch in. The scroll view of the
    /// row takes this frame, so an item at either end of the strip takes a touch in its whole square.
    var topBarTouchStrip: CGRect {
        let overhang = (CameraMetrics.TopBar.touchSize - CameraMetrics.TopBar.buttonSize) / 2
        return topBarViewport.insetBy(dx: -overhang, dy: -overhang)
    }

    /// The width of a row of the given number of items, side by side at the pitch of the slots.
    func topBarContentWidth(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return CGFloat(itemCount - 1) * CameraMetrics.TopBar.pitch + CameraMetrics.TopBar.buttonSize
    }

    /// Whether a row of the given number of items is wider than the strip, so that it scrolls.
    func topBarOverflows(itemCount: Int) -> Bool {
        topBarContentWidth(itemCount: itemCount) > topBarViewport.width + 0.01
    }

    /// The square in the middle of the viewfinder that the small copy of a fresh photo takes off from.
    var captureFlightStart: CGRect {
        let frame = viewfinder
        return Self.square(FlowMetrics.CaptureFlight.startSide, center: CGPoint(x: frame.midX, y: frame.midY))
    }
}
