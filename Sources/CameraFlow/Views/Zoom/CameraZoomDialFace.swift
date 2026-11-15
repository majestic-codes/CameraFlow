//
//  CameraZoomDialFace.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The disc of the zoom dial with its ticks, factor labels, focal lengths and marks, drawn whole in a square of
/// its diameter. The needle and the current value sit on top as separate views.
struct CameraZoomDialFace: View, Animatable {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.colorSchemeContrast) private var contrast
    let zoom: CGFloat
    let scale: ZoomScale
    let lensFactors: [CGFloat]
    let markedFactors: [CGFloat]
    let labelFactors: [CGFloat]
    let focalLengths: [CGFloat: Int]
    /// Degrees clockwise each factor label turns on top of its angle on the dial, so it stays upright.
    var labelRotation: Double

    nonisolated var animatableData: Double {
        get { labelRotation }
        set { labelRotation = newValue }
    }

    private typealias Metrics = CameraMetrics.ZoomDial

    private struct Label {
        let text: Text
        let opacity: Double
        let scale: CGFloat
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: Metrics.radius)
            let geometry = ZoomDialGeometry(center: center, radius: Metrics.radius)
            let disc = CGRect(
                x: center.x - Metrics.radius,
                y: center.y - Metrics.radius,
                width: Metrics.radius * 2,
                height: Metrics.radius * 2
            )
            context.fill(Path(ellipseIn: disc), with: .color(CameraPalette.dialDisc))
            context.drawLayer { layer in
                drawTicks(in: layer, geometry: geometry)
                drawLabels(in: layer, geometry: geometry)
                drawMarks(in: layer, geometry: geometry)
                drawMask(in: layer, size: size, geometry: geometry)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawTicks(in context: GraphicsContext, geometry: ZoomDialGeometry) {
        let ticks = ZoomDialTick.ticks(range: scale.range, emphasizedFactors: lensFactors + markedFactors)
        for tick in ticks {
            let angle = scale.angle(of: tick.factor, current: zoom)
            let outerEnd = geometry.point(at: angle, inset: Metrics.tickOuterInset)
            let innerEnd = geometry.point(at: angle, inset: Metrics.tickInnerInset)
            let isVisible = [outerEnd, innerEnd].contains { end in
                ZoomDialEdgeFade.visibility(at: end, center: geometry.center) > 0
            }
            guard abs(angle) < .pi / 2, isVisible else { continue }
            var line = Path()
            line.move(to: outerEnd)
            line.addLine(to: innerEnd)
            let fall = Metrics.minorTickOpacityFall * Double(scale.normalized(tick.factor))
            let minorOpacity = Metrics.minorTickOpacity - fall
            let opacity = Self.opacity(of: tick.kind, minor: minorOpacity)
            let width = tick.kind == .lens ? Metrics.lensTickWidth : Metrics.tickWidth
            context.stroke(line, with: .color(CameraPalette.label.opacity(opacity)), lineWidth: width)
        }
    }

    private static func opacity(of kind: ZoomDialTick.Kind, minor: Double) -> Double {
        switch kind {
        case .lens: 1
        case .whole: Metrics.wholeTickOpacity
        case .minor: minor
        }
    }

    private func drawLabels(in context: GraphicsContext, geometry: ZoomDialGeometry) {
        let currentTitle = ZoomFactorTitle.dial(zoom, locale: localization.locale)
        let angles = labelFactors.map { scale.angle(of: $0, current: zoom) }
        let hasFocalLength = labelFactors.map { focalLengths[$0] != nil }
        let focalOpacities = ZoomDialLabels.focalLengthOpacities(angles: angles, hasFocalLength: hasFocalLength)
        for (index, factor) in labelFactors.enumerated() {
            let angle = angles[index]
            guard abs(angle) < .pi / 2 else { continue }
            let presence = ZoomDialLabels.presence(at: angle, geometry: geometry)
            let title = Text(ZoomFactorTitle.dial(factor, locale: localization.locale))
                .font(CameraTypography.zoomFactor)
                .kerning(CameraTypography.zoomFactorKerning)
                .foregroundStyle(CameraPalette.label)
            let factorLabel = Label(text: title, opacity: Double(presence * presence * presence), scale: presence)
            let labelPosition = geometry.point(at: angle, inset: Metrics.labelInset)
            let labelAngle = angle + CGFloat(Angle.degrees(labelRotation).radians)
            draw(factorLabel, in: context, at: labelPosition, angle: labelAngle)
            guard let focalLength = focalLengths[factor] else { continue }
            let isCurrent = ZoomFactorTitle.dial(factor, locale: localization.locale) == currentTitle
            let focalTitle = Text(CameraControlText(localization).focalLength(focalLength))
                .font(CameraTypography.focalLength)
                .foregroundStyle(isCurrent ? CameraPalette.accent : minorLabelColor)
            let focalLabel = Label(text: focalTitle, opacity: isCurrent ? 1 : focalOpacities[index], scale: 1)
            draw(focalLabel, in: context, at: geometry.point(at: angle, inset: Metrics.focalLengthInset), angle: angle)
        }
    }

    private var minorLabelColor: Color {
        contrast == .increased ? CameraPalette.dialMinorLabelIncreased : CameraPalette.dialMinorLabel
    }

    private func drawMarks(in context: GraphicsContext, geometry: ZoomDialGeometry) {
        for factor in markedFactors {
            let angle = scale.angle(of: factor, current: zoom)
            guard abs(angle) < .pi / 2 else { continue }
            let presence = ZoomDialLabels.presence(at: angle, geometry: geometry)
            let center = geometry.point(at: angle, inset: Metrics.labelInset)
            let diameter = Metrics.markDiameter * presence
            let dot = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            let opacity = Double(presence * presence * presence)
            context.fill(Path(ellipseIn: dot), with: .color(CameraPalette.label.opacity(opacity)))
        }
    }

    /// Fades the ring toward both sides and parts the ticks around the needle.
    private func drawMask(in context: GraphicsContext, size: CGSize, geometry: ZoomDialGeometry) {
        var mask = context
        mask.blendMode = .destinationOut
        let fade = Gradient(colors: [.clear, .black])
        for isMirrored in [false, true] {
            let side = CGRect(x: isMirrored ? 0 : size.width / 2, y: 0, width: size.width / 2, height: size.height)
            let full = ZoomDialEdgeFade.fullStrengthPoint(center: geometry.center, isMirrored: isMirrored)
            mask.fill(Path(side), with: .linearGradient(fade, startPoint: full, endPoint: geometry.center))
        }
        let notch = Self.notch(top: geometry.center.y - geometry.radius, middle: geometry.center.x)
        mask.fill(notch, with: .color(.black))
    }

    /// The gap in the ticks around the needle: wide above the ticks, narrowing to their inner ends.
    private static func notch(top: CGFloat, middle: CGFloat) -> Path {
        let mouth = Metrics.notchMouth
        let throat = Metrics.notchThroat
        let upperControl = Metrics.notchUpperControl
        let lowerControl = Metrics.notchLowerControl
        let bottom = top + Metrics.tickInnerInset + Metrics.notchDepthBelowTicks
        var bell = Path()
        bell.move(to: CGPoint(x: middle - mouth.width, y: top + mouth.height))
        bell.addLine(to: CGPoint(x: middle + mouth.width, y: top + mouth.height))
        bell.addCurve(
            to: CGPoint(x: middle + throat.width, y: top + throat.height),
            control1: CGPoint(x: middle + upperControl.width, y: top + upperControl.height),
            control2: CGPoint(x: middle + lowerControl.width, y: top + lowerControl.height)
        )
        bell.addLine(to: CGPoint(x: middle + throat.width, y: bottom))
        bell.addLine(to: CGPoint(x: middle - throat.width, y: bottom))
        bell.addLine(to: CGPoint(x: middle - throat.width, y: top + throat.height))
        bell.addCurve(
            to: CGPoint(x: middle - mouth.width, y: top + mouth.height),
            control1: CGPoint(x: middle - lowerControl.width, y: top + lowerControl.height),
            control2: CGPoint(x: middle - upperControl.width, y: top + upperControl.height)
        )
        bell.closeSubpath()
        return bell
    }

    private func draw(_ label: Label, in context: GraphicsContext, at position: CGPoint, angle: CGFloat) {
        guard label.opacity > 0, label.scale > 0 else { return }
        var labelContext = context
        labelContext.opacity = label.opacity
        labelContext.translateBy(x: position.x, y: position.y)
        labelContext.rotate(by: .radians(angle))
        labelContext.scaleBy(x: label.scale, y: label.scale)
        labelContext.draw(label.text, at: .zero, anchor: .center)
    }
}

/// The yellow needle at the top of the dial.
struct ZoomDialNeedle: Shape {

    func path(in bounds: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }
}
#endif
