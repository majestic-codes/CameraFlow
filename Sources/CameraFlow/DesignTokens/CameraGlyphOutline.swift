//
//  CameraGlyphOutline.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// The glyphs the package draws itself where the stock camera has symbols of its own: a timer dial and the dots of
/// the control panel's button, built from circles and lines. The outlines are in points around the centre of the
/// glyph for a symbol of `designPointSize` at the medium scale, and a cut scales them (`CameraGlyph.Cut`). Their lines
/// are as wide as the strokes of the system symbols around them, so they sit among those as one family.
enum CameraGlyphOutline {
    /// The point size the outlines are drawn for.
    static let designPointSize: CGFloat = 22
    /// How much larger the large symbol scale draws a glyph than the medium one, as the system symbols grow.
    static let largeScaleGrowth: CGFloat = 1.293

    // MARK: - Timer dial

    /// The radius of the dial to the middle of its line.
    static let dialRadius: CGFloat = 10.05
    /// Where the opening of the dial starts, in degrees clockwise from the trailing side: the dial is open from there
    /// to its top.
    static let dialOpeningStart: CGFloat = 225
    /// The tick that hangs from the top of the dial towards its centre.
    static let dialTickLength: CGFloat = 2.6
    /// How far each end of the slash of no delay reaches from the centre, across and down.
    static let slashReach: CGFloat = 9.85
    /// Free space between the slash and the ends of the dial on each side of it.
    static let slashClearance: CGFloat = 0.6

    /// The dial of the self-timer: a ring open between its top leading side and its top, with a tick down from the
    /// top. Struck through for no delay, the ring gives way around the slash, which `timerSlash` draws.
    /// - Parameter lineWidth: The width the outline is stroked with, in the points of the outline.
    static func timerDial(isStruckThrough: Bool, lineWidth: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -dialRadius + dialTickLength))
        path.addLine(to: CGPoint(x: 0, y: -dialRadius))
        let top: CGFloat = 270
        let openingStart = dialOpeningStart + 360
        guard isStruckThrough else {
            addDialArc(to: path, from: top, to: openingStart)
            return path
        }
        let gap = slashGapAngle(lineWidth: lineWidth)
        let lowerCrossing: CGFloat = 45 + 360
        let upperCrossing: CGFloat = 225 + 360
        addDialArc(to: path, from: top, to: lowerCrossing - gap)
        path.move(to: point(atDegrees: lowerCrossing + gap))
        addDialArc(to: path, from: lowerCrossing + gap, to: min(openingStart, upperCrossing - gap))
        return path
    }

    /// The slash of no delay, from the top leading corner through the centre to the bottom trailing corner: it
    /// crosses the ring at 225 and 45 degrees.
    static var timerSlash: CGPath {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: -slashReach, y: -slashReach), CGPoint(x: slashReach, y: slashReach)])
        return path
    }

    /// The half of the angle the ring leaves open around the slash: its ends keep the clearance from the slash with
    /// their round caps.
    private static func slashGapAngle(lineWidth: CGFloat) -> CGFloat {
        let reach = min((lineWidth + slashClearance) / dialRadius, 1)
        return asin(reach) * 180 / .pi
    }

    private static func addDialArc(to path: CGMutablePath, from start: CGFloat, to end: CGFloat) {
        path.addArc(
            center: .zero,
            radius: dialRadius,
            startAngle: start * .pi / 180,
            endAngle: end * .pi / 180,
            clockwise: false
        )
    }

    private static func point(atDegrees degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: dialRadius * cos(radians), y: dialRadius * sin(radians))
    }

    // MARK: - Control panel dots

    static let dotDiameter: CGFloat = 5.5
    /// From the centre of one dot to the next, across and down.
    static let dotPitch: CGFloat = 8.4

    /// The button of the control panel: six dots, three across and two down, as the tiles of the panel stand.
    static var controlDots: CGPath {
        let path = CGMutablePath()
        for row in [-0.5, 0.5] {
            for column in [-1.0, 0, 1] {
                let center = CGPoint(x: column * dotPitch, y: row * dotPitch)
                let radius = dotDiameter / 2
                let dot = CGRect(x: center.x - radius, y: center.y - radius, width: dotDiameter, height: dotDiameter)
                path.addEllipse(in: dot)
            }
        }
        return path
    }

    // MARK: - Lettering

    /// How a composed glyph writes its text in the camera font: the size as a share of the point size at each symbol
    /// scale, the width axis of the font, nil for its normal width, and whether the text is one weight heavier than
    /// the lines of the glyph.
    struct Lettering: Equatable {
        let mediumShare: CGFloat
        let largeShare: CGFloat
        let widthAxis: CGFloat?
        let isHeavierThanLines: Bool
    }

    /// The delay in the timer dial, one weight heavier than the ring so that the small digits weigh what it does.
    /// Two digits are narrowed to keep clear of the ring.
    static func delayLettering(digitCount: Int) -> Lettering {
        Lettering(
            mediumShare: 0.582,
            largeShare: 0.578,
            widthAxis: digitCount > 1 ? 88 : nil,
            isHeavierThanLines: true
        )
    }

    /// The ratio in the viewfinder symbol, in the weight of its corners. A ratio of four characters is set smaller
    /// and narrower to stay inside them.
    static func aspectRatioLettering(characterCount: Int) -> Lettering {
        characterCount > 3
            ? Lettering(mediumShare: 0.466, largeShare: 0.472, widthAxis: 83, isHeavierThanLines: false)
            : Lettering(mediumShare: 0.535, largeShare: 0.507, widthAxis: nil, isHeavierThanLines: false)
    }

    // MARK: - Badged symbols

    /// How far a badged symbol moves back towards its leading side at `designPointSize`, at the medium and the
    /// large scale: half of how far its badge stands out of the frame, so that the base and the badge sit centred
    /// together as on the stock camera.
    static func badgeShift(scale: CameraGlyph.Scale) -> CGFloat {
        scale == .large ? 1.63 : 1.72
    }

    // MARK: - Line widths

    /// The width of the strokes of a system symbol of `designPointSize`, by its weight and scale. Bold Text draws a
    /// symbol in the next heavier weight: light becomes regular and regular becomes semibold.
    static func lineWidth(weight: CameraGlyph.Weight, scale: CameraGlyph.Scale, isBold: Bool) -> CGFloat {
        let isLarge = scale == .large
        return switch (weight, isBold) {
        case (.light, false): isLarge ? 1.52 : 1.4
        case (.light, true), (.regular, false): isLarge ? 2 : 1.82
        case (.regular, true): isLarge ? 2.8 : 2.46
        }
    }
}

extension CameraGlyph.Cut {
    /// How much an outline of `CameraGlyphOutline` grows in this cut: by the point size, and by the large scale as
    /// the system symbols grow.
    var outlineScale: CGFloat {
        let growth = scale == .large ? CameraGlyphOutline.largeScaleGrowth : 1
        return pointSize / CameraGlyphOutline.designPointSize * growth
    }

    /// How far a badged symbol of this cut moves towards its leading side, in points of the screen.
    var badgeShift: CGFloat {
        CameraGlyphOutline.badgeShift(scale: scale) * pointSize / CameraGlyphOutline.designPointSize
    }

    /// The width of the lines of an outline in this cut, in points of the screen.
    func lineWidth(isBold: Bool) -> CGFloat {
        let width = CameraGlyphOutline.lineWidth(weight: weight, scale: scale, isBold: isBold)
        return width * pointSize / CameraGlyphOutline.designPointSize
    }

    /// The point size of the text a glyph of this cut writes.
    func textSize(of lettering: CameraGlyphOutline.Lettering) -> CGFloat {
        let share = scale == .large ? lettering.largeShare : lettering.mediumShare
        return share * CameraGlyphOutline.designPointSize * outlineScale
    }
}
