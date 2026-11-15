//
//  PhotoQualityModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("The quality a flow opens with and offers")
struct PhotoQualityModelTests {
    private var standardSize: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.size = .standard
        return output
    }

    @Test("A flow that says nothing has the high quality fixed and the output as it is")
    func defaults() {
        let model = PhotoQualityModel()
        #expect(model.quality == .high)
        #expect(model.offered.isEmpty)
        #expect(model.isUserAdjustable == false)
        #expect(model.isReduced == false)
        #expect(model.output == CameraFlowOutput())
        #expect(model.widestOutput == CameraFlowOutput())
    }

    @Test("An adjustable quality offers every quality that differs and opens with the app's value")
    func adjustable() {
        let model = PhotoQualityModel(setting: CameraFlowSetting(.medium))
        #expect(model.offered == [.high, .medium, .low])
        #expect(model.isUserAdjustable)
        #expect(model.quality == .medium)
        #expect(model.isReduced)
        #expect(model.output.size == .standard)
        #expect(model.widestOutput == CameraFlowOutput())
    }

    @Test("A stored preference opens an adjustable quality and is ignored by a fixed one")
    func preference() {
        #expect(PhotoQualityModel(setting: CameraFlowSetting(.high), preference: .low).quality == .low)
        let fixed = PhotoQualityModel(setting: .fixed(.medium), preference: .low)
        #expect(fixed.quality == .medium)
        #expect(fixed.offered.isEmpty)
        #expect(fixed.isReduced == false)
        #expect(fixed.output.size == .standard)
        #expect(fixed.widestOutput.size == .standard)
    }

    @Test("A quality the output leaves no room for opens as the best one with the same output")
    func notOffered() {
        let model = PhotoQualityModel(setting: CameraFlowSetting(.high), preference: .medium, output: standardSize)
        #expect(model.offered == [.high, .low])
        #expect(model.quality == .high)
        #expect(model.isReduced == false)
        #expect(model.output == standardSize)
    }

    @Test("An output that leaves nothing to choose has no choice, whatever the app allows")
    func nothingToChoose() {
        var output = standardSize
        output.format = .heic(quality: 0.4)
        let model = PhotoQualityModel(setting: CameraFlowSetting(.low), preference: .medium, output: output)
        #expect(model.offered.isEmpty)
        #expect(model.isUserAdjustable == false)
        #expect(model.quality == .high)
        #expect(model.output == output)
    }

    @Test("The quality model offers and applies the levels of the app")
    func model() {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8))
        levels.low = CameraFlowQualityLevel(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6))
        let model = PhotoQualityModel(setting: CameraFlowSetting(.medium), levels: levels)
        #expect(model.offered == [.high, .medium, .low])
        #expect(model.output == CameraFlowOutput(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)))
        #expect(model.select(.low))
        #expect(model.output == CameraFlowOutput(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6)))
        #expect(model.widestOutput == CameraFlowOutput())
    }

    @Test("Only an offered quality that differs from the current one is taken")
    func select() {
        let model = PhotoQualityModel(setting: CameraFlowSetting(.high), output: standardSize)
        #expect(model.select(.medium) == false)
        #expect(model.select(.high) == false)
        #expect(model.select(.low))
        #expect(model.quality == .low)
        #expect(model.output.format == .heic(quality: 0.5))
        let fixed = PhotoQualityModel()
        #expect(fixed.select(.low) == false)
        #expect(fixed.quality == .high)
    }
}
