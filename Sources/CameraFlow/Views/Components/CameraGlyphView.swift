//
//  CameraGlyphView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A camera glyph drawn in the current foreground style, centred in the space it is given: a system symbol, a ratio
/// written in the viewfinder symbol, or one of the package's own outlines with the text it holds.
struct CameraGlyphView: View {
    let glyph: CameraGlyph
    var placement: CameraGlyph.Placement?

    @Environment(\.legibilityWeight) private var legibilityWeight

    var body: some View {
        let cut = glyph.cut(in: placement ?? glyph.defaultPlacement)
        artwork(in: cut)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func artwork(in cut: CameraGlyph.Cut) -> some View {
        switch glyph.artwork {
        case let .symbol(name):
            symbol(name, in: cut)
        case let .badgedSymbol(name):
            symbol(name, in: cut)
                .offset(x: -cut.badgeShift)
        case let .aspectRatio(ratio):
            ZStack {
                symbol(CameraGlyph.viewfinderSymbol, in: cut)
                text(ratio, lettering: CameraGlyphOutline.aspectRatioLettering(characterCount: ratio.count), in: cut)
            }
        case let .timer(seconds):
            let lineWidth = cut.lineWidth(isBold: legibilityWeight == .bold)
            let dial = CameraGlyphOutline.timerDial(
                isStruckThrough: seconds == nil,
                lineWidth: lineWidth / cut.outlineScale
            )
            ZStack {
                stroked(dial, lineWidth: lineWidth, in: cut)
                if let seconds {
                    let digits = String(seconds)
                    text(digits, lettering: CameraGlyphOutline.delayLettering(digitCount: digits.count), in: cut)
                } else {
                    stroked(CameraGlyphOutline.timerSlash, lineWidth: lineWidth, in: cut)
                }
            }
        case .controlDots:
            let dots = GlyphOutline(outline: CameraGlyphOutline.controlDots, scale: cut.outlineScale)
            dots
                .fill()
                .frame(size: dots.box(lineWidth: 0))
        }
    }

    private func symbol(_ name: String, in cut: CameraGlyph.Cut) -> some View {
        Image(systemName: name)
            .font(.system(size: cut.pointSize, weight: cut.weight.fontWeight))
            .imageScale(cut.scale.imageScale)
            .accessibilityHidden(true)
    }

    private func text(_ text: String, lettering: CameraGlyphOutline.Lettering, in cut: CameraGlyph.Cut) -> some View {
        let style = CameraTextStyle(
            size: cut.textSize(of: lettering),
            weight: textWeight(of: lettering, in: cut).rawValue,
            widthAxis: lettering.widthAxis
        )
        return Text(verbatim: text)
            .font(CameraTypography.font(style))
            .fixedSize()
    }

    /// The weight of the text a glyph writes, which Bold Text makes heavier as it makes the symbols: the camera font
    /// does not follow Bold Text by itself.
    private func textWeight(of lettering: CameraGlyphOutline.Lettering, in cut: CameraGlyph.Cut) -> UIFont.Weight {
        switch (cut.weight, lettering.isHeavierThanLines, legibilityWeight == .bold) {
        case (.light, false, false): .light
        case (.light, false, true), (.light, true, false), (.regular, false, false): .regular
        case (.regular, true, false): .medium
        case (.light, true, true), (.regular, false, true): .semibold
        case (.regular, true, true): .bold
        }
    }

    private func stroked(_ outline: CGPath, lineWidth: CGFloat, in cut: CameraGlyph.Cut) -> some View {
        let shape = GlyphOutline(outline: outline, scale: cut.outlineScale)
        return shape
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(size: shape.box(lineWidth: lineWidth))
    }
}

/// An outline of `CameraGlyphOutline`, which is drawn around the origin, scaled and moved to the centre of the space.
private struct GlyphOutline: Shape {
    let outline: Path

    init(outline: CGPath, scale: CGFloat) {
        self.outline = Path(outline).applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    func path(in bounds: CGRect) -> Path {
        outline.offsetBy(dx: bounds.midX, dy: bounds.midY)
    }

    /// The box centred on the origin that holds the outline with its lines.
    func box(lineWidth: CGFloat) -> CGSize {
        let bounds = outline.boundingRect
        let halfWidth = max(abs(bounds.minX), abs(bounds.maxX))
        let halfHeight = max(abs(bounds.minY), abs(bounds.maxY))
        return CGSize(width: halfWidth * 2 + lineWidth, height: halfHeight * 2 + lineWidth)
    }
}

private extension View {

    func frame(size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}

private extension CameraGlyph.Weight {
    var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        }
    }
}

private extension CameraGlyph.Scale {
    var imageScale: Image.Scale {
        switch self {
        case .medium: .medium
        case .large: .large
        }
    }
}
#endif
