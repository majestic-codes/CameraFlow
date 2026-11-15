//
//  CameraGlyphTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Camera glyphs")
struct CameraGlyphTests {
    struct PlacedCut: Sendable, CustomTestStringConvertible {
        let glyph: CameraGlyph
        let placement: CameraGlyph.Placement
        let cut: CameraGlyph.Cut

        init(
            _ glyph: CameraGlyph,
            _ placement: CameraGlyph.Placement,
            _ pointSize: CGFloat,
            _ weight: CameraGlyph.Weight,
            _ scale: CameraGlyph.Scale
        ) {
            self.glyph = glyph
            self.placement = placement
            cut = CameraGlyph.Cut(pointSize: pointSize, weight: weight, scale: scale)
        }

        var testDescription: String {
            "\(glyph) \(placement)"
        }
    }

    @Test(
        "A placement draws a glyph in the stock size, weight and symbol scale",
        arguments: [
            PlacedCut(.flashOff, .topBar, 18.5, .regular, .medium),
            PlacedCut(.timer3, .topBar, 18.5, .regular, .medium),
            PlacedCut(.flashOff, .optionRow, 22, .regular, .medium),
            PlacedCut(.aspect4x3, .optionRow, 22, .regular, .medium),
            PlacedCut(.flashOff, .tile, 22, .light, .large),
            PlacedCut(.exposure, .tile, 22, .light, .large),
            PlacedCut(.more, .button, 17, .regular, .medium),
            PlacedCut(.back, .button, 17, .regular, .medium),
            PlacedCut(.flip, .button, 17, .regular, .large)
        ]
    )
    func cut(subject: PlacedCut) {
        #expect(subject.glyph.cut(in: subject.placement) == subject.cut)
    }

    @Test(
        "A glyph with a public symbol is that symbol, the others are composed or drawn by the package",
        arguments: [
            (CameraGlyph.flashAuto, CameraGlyph.Artwork.badgedSymbol("bolt.badge.automatic.fill")),
            (.flashAutoUnlit, .badgedSymbol("bolt.badge.automatic")),
            (.flashOn, .symbol("bolt.fill")),
            (.flashOff, .symbol("bolt.slash.fill")),
            (.flashUnavailable, .badgedSymbol("bolt.trianglebadge.exclamationmark.fill")),
            (.livePhotoOn, .symbol("livephoto")),
            (.livePhotoOff, .symbol("livephoto.slash")),
            (.aspect4x3, .aspectRatio("4:3")),
            (.aspect16x9, .aspectRatio("16:9")),
            (.aspect1x1, .aspectRatio("1:1")),
            (.timerOff, .timer(seconds: nil)),
            (.timer3, .timer(seconds: 3)),
            (.timer5, .timer(seconds: 5)),
            (.timer10, .timer(seconds: 10)),
            (.exposure, .symbol("plusminus")),
            (.more, .controlDots),
            (.flip, .symbol("arrow.triangle.2.circlepath")),
            (.back, .symbol("chevron.backward"))
        ]
    )
    func artwork(glyph: CameraGlyph, artwork: CameraGlyph.Artwork) {
        #expect(glyph.artwork == artwork)
    }

    @Test("Every setting value a timer offers is written in its dial")
    func timerDelays() {
        let delays = CameraFlowTimer.allCases.map { CameraGlyph(timer: $0).artwork }
        let written = CameraFlowTimer.allCases.map { timer in
            CameraGlyph.Artwork.timer(seconds: timer == .off ? nil : timer.rawValue)
        }
        #expect(delays == written)
    }

    @Test("Every aspect ratio is written as the setting names it")
    func aspectRatios() {
        let ratios = CameraFlowAspectRatio.allCases.map { CameraGlyph(aspectRatio: $0).artwork }
        #expect(ratios == CameraFlowAspectRatio.allCases.map { CameraGlyph.Artwork.aspectRatio($0.rawValue) })
    }

    #if os(macOS)
    @Test("No artwork ships with the package: its resources hold no image catalog")
    func noImageCatalog() throws {
        let resources = try SourceTree.checkout().directory.appendingPathComponent("Resources")
        let names = try FileManager.default.contentsOfDirectory(atPath: resources.path)
        #expect(names.contains { $0.hasSuffix(".xcassets") } == false, "Image catalogs in Resources: \(names)")
    }
    #endif
}
