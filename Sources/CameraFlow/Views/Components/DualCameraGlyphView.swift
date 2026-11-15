//
//  DualCameraGlyphView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The glyph of the second camera's circle in the current foreground style: the viewfinder as a rounded square with
/// the circle as a dot in its top trailing corner, or the empty viewfinder for the circle off.
struct DualCameraGlyphView: View {
    var hasCircle = true
    var pointSize = CameraMetrics.Symbol.topBarPointSize
    var weight = Font.Weight.regular

    var body: some View {
        let metrics = FlowMetrics.DualCameraToggle.self
        let scale = pointSize / CameraMetrics.Symbol.topBarPointSize
        ZStack {
            FlowSymbolView(symbol: .dualCameraFrame, pointSize: pointSize, weight: weight)
            if hasCircle {
                Circle()
                    .frame(width: metrics.dotDiameter * scale, height: metrics.dotDiameter * scale)
                    .offset(x: metrics.dotOffset * scale, y: -metrics.dotOffset * scale)
            }
        }
        .accessibilityHidden(true)
    }
}
#endif
