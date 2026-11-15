//
//  CameraGlyphOutlineTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The package's own glyph outlines and the cuts that size them, against the strokes of the system symbols measured
/// at 22 pt on macOS 27.
@Suite("Camera glyph outlines")
struct CameraGlyphOutlineTests {
    private typealias Outline = CameraGlyphOutline

    @Test("The timer dial is a ring of the dial radius with its tick inside")
    func dialBounds() {
        let radius = Outline.dialRadius
        let dial = Outline.timerDial(isStruckThrough: false, lineWidth: 1.82).boundingBoxOfPath
        expectClose(dial, CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    }

    @Test("The ring of the dial starts at the tick on its top and ends where its opening starts")
    func dialOpening() {
        let path = Outline.timerDial(isStruckThrough: false, lineWidth: 1.82)
        let points = Self.endPoints(of: path)
        let radius = Outline.dialRadius
        let opening = Outline.dialOpeningStart * .pi / 180
        let end = CGPoint(x: radius * cos(opening), y: radius * sin(opening))
        #expect(points.first == CGPoint(x: 0, y: -radius + Outline.dialTickLength))
        #expect(points.dropFirst().first == CGPoint(x: 0, y: -radius))
        #expect(Self.distance(path.currentPoint, end) < 0.001)
    }

    @Test("Struck through, the ring keeps clear of the slash with its round ends", arguments: [1.4, 1.82, 2.46, 2.8])
    func slashClearance(lineWidth: Double) throws {
        let width = CGFloat(lineWidth)
        let path = Outline.timerDial(isStruckThrough: true, lineWidth: width)
        let nearest = try #require(Self.endPoints(of: path).map(Self.distanceFromSlash).min())
        #expect(nearest >= width + Outline.slashClearance - 0.001)
    }

    @Test("The slash runs through the centre from the top leading corner and stays within the ring")
    func slash() {
        let reach = Outline.slashReach
        let expected = CGRect(x: -reach, y: -reach, width: reach * 2, height: reach * 2)
        expectClose(Outline.timerSlash.boundingBoxOfPath, expected)
        #expect(reach <= Outline.dialRadius)
    }

    @Test("The button of the control panel is six dots, three across and two down, around the centre")
    func controlDots() {
        let dots = Outline.controlDots
        let pitch = Outline.dotPitch
        let diameter = Outline.dotDiameter
        let expected = CGRect(
            x: -pitch - diameter / 2,
            y: -pitch / 2 - diameter / 2,
            width: pitch * 2 + diameter,
            height: pitch + diameter
        )
        expectClose(dots.boundingBoxOfPath, expected)
        var dotCount = 0
        dots.applyWithBlock { element in
            if element.pointee.type == .moveToPoint {
                dotCount += 1
            }
        }
        #expect(dotCount == 6)
    }

    @Test(
        "A cut scales the outlines by its point size, and the large scale grows them as it grows the symbols",
        arguments: [
            (CameraGlyph.Cut(pointSize: 22, weight: .regular, scale: .medium), 1.0),
            (CameraGlyph.Cut(pointSize: 18.5, weight: .regular, scale: .medium), 18.5 / 22),
            (CameraGlyph.Cut(pointSize: 22, weight: .light, scale: .large), 1.293),
            (CameraGlyph.Cut(pointSize: 17, weight: .regular, scale: .medium), 17.0 / 22)
        ]
    )
    func outlineScale(cut: CameraGlyph.Cut, scale: Double) {
        expectClose(cut.outlineScale, scale, tolerance: 0.0001)
    }

    @Test(
        "The lines are as wide as the strokes of a symbol of the weight and scale, and Bold Text draws the next weight",
        arguments: [
            (CameraGlyph.Weight.light, CameraGlyph.Scale.medium, false, 1.4),
            (.light, .large, false, 1.52),
            (.regular, .medium, false, 1.82),
            (.regular, .large, false, 2.0),
            (.light, .medium, true, 1.82),
            (.light, .large, true, 2.0),
            (.regular, .medium, true, 2.46),
            (.regular, .large, true, 2.8)
        ]
    )
    func lineWidth(weight: CameraGlyph.Weight, scale: CameraGlyph.Scale, isBold: Bool, width: Double) {
        #expect(Double(Outline.lineWidth(weight: weight, scale: scale, isBold: isBold)) == width)
    }

    @Test("A cut of a smaller point size draws thinner lines in proportion")
    func cutLineWidth() {
        let topBar = CameraGlyph.Cut(pointSize: 18.5, weight: .regular, scale: .medium)
        expectClose(topBar.lineWidth(isBold: false), 1.82 * 18.5 / 22, tolerance: 0.0001)
    }

    @Test("Two digits of a delay are narrowed, one is not, and both are a weight heavier than the ring")
    func delayLettering() {
        let one = Outline.delayLettering(digitCount: 1)
        let two = Outline.delayLettering(digitCount: 2)
        #expect(one.widthAxis == nil)
        #expect(two.widthAxis == 88)
        #expect(one.isHeavierThanLines && two.isHeavierThanLines)
    }

    @Test("A ratio of four characters is set smaller and narrower than one of three, in the weight of the corners")
    func aspectRatioLettering() {
        let three = Outline.aspectRatioLettering(characterCount: 3)
        let four = Outline.aspectRatioLettering(characterCount: 4)
        #expect(four.mediumShare < three.mediumShare)
        #expect(three.widthAxis == nil)
        #expect(four.widthAxis == 83)
        #expect(three.isHeavierThanLines == false && four.isHeavierThanLines == false)
    }

    @Test("The text of a glyph grows with the point size and the large scale")
    func textSize() {
        let lettering = Outline.delayLettering(digitCount: 1)
        let row = CameraGlyph.Cut(pointSize: 22, weight: .regular, scale: .medium)
        let tile = CameraGlyph.Cut(pointSize: 22, weight: .light, scale: .large)
        expectClose(row.textSize(of: lettering), 0.582 * 22, tolerance: 0.0001)
        expectClose(tile.textSize(of: lettering), 0.578 * 22 * 1.293, tolerance: 0.0001)
    }

    @Test("A badged symbol moves back by half of its badge, in proportion to its point size")
    func badgeShift() {
        let row = CameraGlyph.Cut(pointSize: 22, weight: .regular, scale: .medium)
        let topBar = CameraGlyph.Cut(pointSize: 18.5, weight: .regular, scale: .medium)
        let tile = CameraGlyph.Cut(pointSize: 22, weight: .light, scale: .large)
        expectClose(row.badgeShift, 1.72, tolerance: 0.0001)
        expectClose(topBar.badgeShift, 1.72 * 18.5 / 22, tolerance: 0.0001)
        expectClose(tile.badgeShift, 1.63, tolerance: 0.0001)
    }

    private static func endPoints(of path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            let pointer = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint: points.append(pointer[0])
            case .addQuadCurveToPoint: points.append(pointer[1])
            case .addCurveToPoint: points.append(pointer[2])
            case .closeSubpath: break
            @unknown default: break
            }
        }
        return points
    }

    /// The distance from the line of the slash, which runs through the centre at 45 degrees.
    private static func distanceFromSlash(_ point: CGPoint) -> CGFloat {
        abs(point.x - point.y) / 2.squareRoot()
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
