//
//  LensRowLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where the lens buttons stand in their row, and which one a point of the row falls on: the active lens in the
/// middle of the row and the others a pitch apart, wherever the row has slid. Points are in the coordinates of the
/// screen layout.
struct LensRowLayout: Equatable, Sendable {
    /// The row of the buttons.
    let row: CGRect
    let lensCount: Int
    /// The lens whose button stands in the middle of the row.
    let activeIndex: Int

    private typealias Metrics = CameraMetrics.LensRow

    /// How far the button of a lens stands from the middle of the row, to the right for a longer lens.
    func offset(of index: Int) -> CGFloat {
        CGFloat(index - activeIndex) * Metrics.pitch
    }

    /// The middle of the button of a lens.
    func centerX(of index: Int) -> CGFloat {
        row.midX + offset(of: index)
    }

    /// The frame that takes the touches of the row and of every button, however far the row has slid, with the
    /// slop of a finger around it.
    var touchFrame: CGRect {
        let radius = Metrics.buttonDiameter / 2
        let buttons = lensCount > 0
            ? CGRect(
                x: centerX(of: 0) - radius,
                y: row.minY,
                width: centerX(of: lensCount - 1) - centerX(of: 0) + 2 * radius,
                height: row.height
            )
            : row
        return buttons.union(row).insetBy(dx: -Metrics.touchSlop, dy: -Metrics.touchSlop)
    }

    /// The lens whose button a point falls on, by the nearest slot of the row; nil off the row or past the ends.
    func lensIndex(at point: CGPoint) -> Int? {
        let slop = Metrics.touchSlop
        guard point.y >= row.minY - slop, point.y <= row.maxY + slop else { return nil }
        let slot = ((point.x - row.midX) / Metrics.pitch).rounded()
        let index = activeIndex + Int(slot)
        return (0..<lensCount).contains(index) ? index : nil
    }
}
