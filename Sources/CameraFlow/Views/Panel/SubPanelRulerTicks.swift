//
//  SubPanelRulerTicks.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Ticks of the exposure ruler: one tick per third of a stop, every third one (a whole stop) brighter, fading out
/// towards the ends, with the yellow centre mark on top. Drawn across the whole card, centred on its width.
struct SubPanelRulerTicks: View {
    let bias: Double
    /// The exposure bias range the ticks cover.
    let range: ClosedRange<Double>

    static let tickPitch = SubPanelRulerScale.tickPitch
    static let ticksPerStop = SubPanelRulerScale.ticksPerStop
    private typealias Metrics = CameraMetrics.SubPanel
    private static let tickWidth = Metrics.rulerTickWidth
    /// Bottom of the ticks and of the centre mark from the top of the card: the mark is centred on the option line.
    static let bottom = Metrics.optionCenterY + Metrics.rulerCenterMarkHeight / 2

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let indices = SubPanelRulerScale.tickIndices(in: range)
            let shift = bias * Double(Self.ticksPerStop)
            for index in indices {
                let distance = abs(Double(index) - shift)
                let fade = SubPanelRulerScale.fade(atDistance: distance)
                guard fade > 0 else { continue }
                let isMajor = index.isMultiple(of: Self.ticksPerStop)
                let opacity = (isMajor ? Metrics.rulerMajorTickOpacity : Metrics.rulerMinorTickOpacity) * fade
                let tickCenter = centerX + CGFloat(Double(index) - shift) * Self.tickPitch
                let tickFrame = CGRect(
                    x: tickCenter - Self.tickWidth / 2,
                    y: Self.bottom - Metrics.rulerTickHeight,
                    width: Self.tickWidth,
                    height: Metrics.rulerTickHeight
                )
                context.fill(
                    Path(roundedRect: tickFrame, cornerRadius: Self.tickWidth / 2),
                    with: .color(CameraPalette.label.opacity(opacity))
                )
            }
            let mark = CGRect(
                x: centerX - Self.tickWidth / 2,
                y: Self.bottom - Metrics.rulerCenterMarkHeight,
                width: Self.tickWidth,
                height: Metrics.rulerCenterMarkHeight
            )
            context.fill(Path(roundedRect: mark, cornerRadius: Self.tickWidth / 2), with: .color(CameraPalette.accent))
        }
        .accessibilityHidden(true)
    }
}
#endif
