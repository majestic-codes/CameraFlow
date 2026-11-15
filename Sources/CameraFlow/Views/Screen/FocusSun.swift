//
//  FocusSun.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The exposure sun: a disc and eight rays one point wide, drawn as the stock camera of iOS 27 draws it. The disc
/// and the rays grow with the position on the rail (`FocusReticleLayout.Sun`). It is centred in its rectangle.
struct FocusSun: Shape {
    static let rayCount = 8
    static let rayWidth: CGFloat = 1

    /// Position on the rail, 0 at the bottom and 1 at the top.
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func path(in bounds: CGRect) -> Path {
        let sun = FocusReticleLayout.Sun(value: value)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - sun.discRadius,
            y: center.y - sun.discRadius,
            width: sun.discRadius * 2,
            height: sun.discRadius * 2
        ))
        let ray = CGRect(
            x: center.x + sun.rayStart,
            y: center.y - Self.rayWidth / 2,
            width: sun.rayLength,
            height: Self.rayWidth
        )
        for index in 0..<Self.rayCount {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(Self.rayCount)
            let rotation = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: angle)
                .translatedBy(x: -center.x, y: -center.y)
            path.addPath(Path(ray).applying(rotation))
        }
        return path
    }
}
#endif
