//
//  ZoomScale.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

struct ZoomScale: Equatable, Sendable {
    static let sweep = CGFloat.pi / 2

    let range: ClosedRange<CGFloat>

    func normalized(_ zoom: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        return log(zoom / range.lowerBound) / log(range.upperBound / range.lowerBound)
    }

    func zoom(normalized value: CGFloat) -> CGFloat {
        range.lowerBound * pow(range.upperBound / range.lowerBound, min(max(value, 0), 1))
    }

    func angle(of zoom: CGFloat, current: CGFloat) -> CGFloat {
        (normalized(zoom) - normalized(current)) * Self.sweep
    }

    func clamped(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, range.lowerBound), range.upperBound)
    }
}
