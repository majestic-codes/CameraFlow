//
//  CameraGlyphSettingsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Camera glyphs of the settings")
struct CameraGlyphSettingsTests {

    @Test(
        "Every flash mode has its own glyph",
        arguments: [(CameraFlowFlashMode.auto, CameraGlyph.flashAuto), (.alwaysOn, .flashOn), (.off, .flashOff)]
    )
    func flash(mode: CameraFlowFlashMode, glyph: CameraGlyph) {
        #expect(CameraGlyph(flashMode: mode) == glyph)
    }

    @Test(
        "The Flash indicator outlines Auto while the flash would not fire, for people who differentiate without colour",
        arguments: [
            (CameraFlowFlashMode.auto, false, true, CameraGlyph.flashAutoUnlit),
            (.auto, true, true, .flashAuto),
            (.auto, false, false, .flashAuto),
            (.auto, true, false, .flashAuto),
            (.alwaysOn, true, true, .flashOn),
            (.off, false, true, .flashOff)
        ]
    )
    func flashIndicator(mode: CameraFlowFlashMode, isLit: Bool, withoutColor: Bool, glyph: CameraGlyph) {
        #expect(CameraGlyph(flashMode: mode, isLit: isLit, differentiatesWithoutColor: withoutColor) == glyph)
    }

    @Test("Live Photo has a glyph for on and one for off")
    func livePhoto() {
        #expect(CameraGlyph(isLivePhotoOn: true) == .livePhotoOn)
        #expect(CameraGlyph(isLivePhotoOn: false) == .livePhotoOff)
    }

    @Test(
        "Every aspect ratio has its own glyph",
        arguments: [
            (CameraFlowAspectRatio.fourByThree, CameraGlyph.aspect4x3),
            (.sixteenByNine, .aspect16x9),
            (.square, .aspect1x1)
        ]
    )
    func aspectRatio(aspectRatio: CameraFlowAspectRatio, glyph: CameraGlyph) {
        #expect(CameraGlyph(aspectRatio: aspectRatio) == glyph)
    }

    @Test(
        "Every timer delay has its own glyph",
        arguments: [
            (CameraFlowTimer.off, CameraGlyph.timerOff),
            (.threeSeconds, .timer3),
            (.fiveSeconds, .timer5),
            (.tenSeconds, .timer10)
        ]
    )
    func timer(timer: CameraFlowTimer, glyph: CameraGlyph) {
        #expect(CameraGlyph(timer: timer) == glyph)
    }

    @Test("The glyphs of the settings are distinct, so no two values look the same")
    func distinct() {
        let flash = Set(CameraFlowFlashMode.allCases.map { CameraGlyph(flashMode: $0) })
        let aspect = Set(CameraFlowAspectRatio.allCases.map { CameraGlyph(aspectRatio: $0) })
        let timer = Set(CameraFlowTimer.allCases.map { CameraGlyph(timer: $0) })
        #expect(flash.count == CameraFlowFlashMode.allCases.count)
        #expect(aspect.count == CameraFlowAspectRatio.allCases.count)
        #expect(timer.count == CameraFlowTimer.allCases.count)
    }

    @Test(
        "A glyph drawn without a placement goes where the stock Camera draws it",
        arguments: [
            (CameraGlyph.flashAuto, CameraGlyph.Placement.topBar),
            (.flashAutoUnlit, .topBar),
            (.livePhotoOff, .topBar),
            (.aspect16x9, .optionRow),
            (.timer10, .optionRow),
            (.exposure, .tile),
            (.more, .button),
            (.flip, .button),
            (.back, .button)
        ]
    )
    func defaultPlacement(glyph: CameraGlyph, placement: CameraGlyph.Placement) {
        #expect(glyph.defaultPlacement == placement)
    }
}
