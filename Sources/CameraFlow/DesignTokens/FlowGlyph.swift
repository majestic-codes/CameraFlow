//
//  FlowGlyph.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The glyphs of the flow's own buttons: outlines to stroke, in points around the centre of the button, as the
/// approved mock-up draws them.
enum FlowGlyph {
    case cross
    case checkmark
    case library
    case trash
    case plus
    case undo
    case redo

    var lineWidth: CGFloat {
        switch self {
        case .cross: 2.1
        case .checkmark: 2.4
        case .library: 1.6
        case .trash, .undo, .redo: 1.9
        case .plus: 2.4
        }
    }

    var outline: CGPath {
        let path = CGMutablePath()
        switch self {
        case .cross:
            path.addLines(between: [CGPoint(x: -6.5, y: -6.5), CGPoint(x: 6.5, y: 6.5)])
            path.addLines(between: [CGPoint(x: 6.5, y: -6.5), CGPoint(x: -6.5, y: 6.5)])
        case .checkmark:
            path.addLines(between: [CGPoint(x: -7.5, y: 0.5), CGPoint(x: -2.5, y: 5.5), CGPoint(x: 7.5, y: -5.5)])
        case .library:
            Self.addLibraryCards(to: path)
        case .trash:
            Self.addTrash(to: path)
        case .plus:
            path.addLines(between: [CGPoint(x: -9, y: 0), CGPoint(x: 9, y: 0)])
            path.addLines(between: [CGPoint(x: 0, y: -9), CGPoint(x: 0, y: 9)])
        case .undo:
            Self.addTurningArrow(to: path, isMirrored: false)
        case .redo:
            Self.addTurningArrow(to: path, isMirrored: true)
        }
        return path
    }

    /// The arrow of undo: a line that comes back around a half circle and ends in a head on the leading side. The
    /// arrow of redo is its mirror image. The mock-up draws both a point above the centre of the button.
    private static func addTurningArrow(to path: CGMutablePath, isMirrored: Bool) {
        let side: CGFloat = isMirrored ? -1 : 1
        let tip = CGPoint(x: -6 * side, y: -3)
        path.move(to: tip)
        path.addLine(to: CGPoint(x: 2.5 * side, y: -3))
        path.addArc(
            center: CGPoint(x: 2.5 * side, y: 1.5),
            radius: 4.5,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: isMirrored
        )
        path.addLine(to: CGPoint(x: -2 * side, y: 6))
        path.addLines(between: [tip, CGPoint(x: -2.5 * side, y: -6.5)])
        path.addLines(between: [tip, CGPoint(x: -2.5 * side, y: 0.5)])
    }

    /// A bin under its lid with a handle, and two ribs on the bin.
    private static func addTrash(to path: CGMutablePath) {
        path.addLines(between: [CGPoint(x: -7.5, y: -5.5), CGPoint(x: 7.5, y: -5.5)])
        let handle = [CGPoint(x: -3, y: -5.5), CGPoint(x: -3, y: -8), CGPoint(x: 3, y: -8), CGPoint(x: 3, y: -5.5)]
        path.addLines(between: handle)
        let bin = [CGPoint(x: -5.8, y: -5.5), CGPoint(x: -4.9, y: 8), CGPoint(x: 4.9, y: 8), CGPoint(x: 5.8, y: -5.5)]
        path.addLines(between: bin)
        path.addLines(between: [CGPoint(x: -2, y: -2), CGPoint(x: -2, y: 4.5)])
        path.addLines(between: [CGPoint(x: 2, y: -2), CGPoint(x: 2, y: 4.5)])
    }

    /// Two photo cards: the front one whole, and the top and trailing edges of the one behind it.
    private static func addLibraryCards(to path: CGMutablePath) {
        let cornerRadius: CGFloat = 3
        let front = CGRect(x: -10, y: -7, width: 17, height: 13)
        path.addRoundedRect(in: front, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        path.move(to: CGPoint(x: -6, y: -10))
        path.addLine(to: CGPoint(x: 9, y: -10))
        path.addArc(tangent1End: CGPoint(x: 12, y: -10), tangent2End: CGPoint(x: 12, y: -7), radius: cornerRadius)
        path.addLine(to: CGPoint(x: 12, y: 3))
    }
}
