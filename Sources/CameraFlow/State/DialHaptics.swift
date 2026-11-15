//
//  DialHaptics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Decides when the dial ticks: on every labelled factor and on every whole factor before the last label.
struct DialHaptics {
    private let values: [CGFloat]
    private let epsilons: [CGFloat]
    private let snapIndexes: Set<Int>
    private var lastZone: Int?

    init(labeledFactors: [CGFloat], snapFactors: [CGFloat], scale: ZoomScale, radius: CGFloat) {
        var values = Array(labeledFactors.dropLast())
        if let last = labeledFactors.last {
            if let beforeLast = values.last {
                var whole = beforeLast.rounded(.down) + 1
                while whole < last {
                    values.append(whole)
                    whole += 1
                }
            }
            values.append(last)
        }
        let step = radius > 0 ? 2 / (radius * ZoomScale.sweep) : 0
        self.values = values
        epsilons = values.enumerated().map { index, value in
            let normalized = scale.normalized(value)
            return index == values.count - 1
                ? value - scale.zoom(normalized: normalized - step)
                : scale.zoom(normalized: normalized + step) - value
        }
        snapIndexes = Set(values.indices.filter { snapFactors.contains(values[$0]) })
    }

    mutating func update(zoom: CGFloat) -> Bool {
        var zone = -1
        for (index, value) in values.enumerated() {
            guard zoom >= value else { break }
            zone += 1
            if zoom > value + (snapIndexes.contains(index) ? 0 : epsilons[index]) {
                zone += 1
            }
        }
        defer { lastZone = zone }
        guard let lastZone, zone != lastZone else { return false }
        return zone.isMultiple(of: 2) || abs(zone - lastZone) >= 2
    }
}
