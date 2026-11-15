//
//  CameraFlowQualityLevelsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Quality levels: what the app says medium and low mean", .timeLimit(.minutes(1)))
struct CameraFlowQualityLevelsTests {
    private static var custom: CameraFlowQualityLevels {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8))
        levels.low = CameraFlowQualityLevel(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6))
        return levels
    }

    @Test("The default levels are 1920 pixels, the medium one in the output's format and the low one a HEIC at 0.5")
    func defaults() {
        let levels = CameraFlowQualityLevels()
        #expect(levels.medium == CameraFlowQualityLevel(size: .standard))
        #expect(levels.medium.format == .original)
        #expect(levels.low == CameraFlowQualityLevel(size: .standard, format: .heic(quality: 0.5)))
        #expect(CameraFlowConfiguration().photoQualityLevels == levels)
        #expect(levels.level(of: .high) == nil)
    }

    struct NarrowingCase: Sendable, CustomTestStringConvertible {
        let level: CameraFlowQualityLevel
        let appOutput: CameraFlowOutput
        let expected: CameraFlowOutput
        let testDescription: String
    }

    static let narrowingCases = [
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)),
            appOutput: CameraFlowOutput(),
            expected: CameraFlowOutput(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)),
            testDescription: "an untouched output takes the level's size and format"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)),
            appOutput: CameraFlowOutput(size: .longSide(maximum: 1000)),
            expected: CameraFlowOutput(size: .longSide(maximum: 1000), format: .jpeg(quality: 0.8)),
            testDescription: "a smaller output keeps its size"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)),
            appOutput: CameraFlowOutput(size: .longSide(maximum: 4000), format: .heic(quality: 0.9)),
            expected: CameraFlowOutput(size: .longSide(maximum: 2048), format: .heic(quality: 0.8)),
            testDescription: "an output with a format keeps the format at the lower quality"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)),
            appOutput: CameraFlowOutput(format: .jpeg(quality: 0.4)),
            expected: CameraFlowOutput(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.4)),
            testDescription: "an output that compresses more keeps its own quality"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .longSide(maximum: 1280)),
            appOutput: CameraFlowOutput(format: .jpeg(quality: 0.7), metadata: .stripped),
            expected: CameraFlowOutput(
                size: .longSide(maximum: 1280),
                format: .jpeg(quality: 0.7),
                metadata: .stripped
            ),
            testDescription: "a level without a format changes the size alone, and the metadata is the output's"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .original, format: .jpeg(quality: 0.7)),
            appOutput: CameraFlowOutput(),
            expected: CameraFlowOutput(format: .jpeg(quality: 0.7)),
            testDescription: "a level of the original size encodes the photo again at the size it has"
        ),
        NarrowingCase(
            level: CameraFlowQualityLevel(size: .original, format: .jpeg(quality: 0.7)),
            appOutput: CameraFlowOutput(size: .longSide(maximum: 1000)),
            expected: CameraFlowOutput(size: .longSide(maximum: 1000), format: .jpeg(quality: 0.7)),
            testDescription: "a level of the original size keeps the output's limit"
        )
    ]

    @Test("A level only narrows the output of the app", arguments: narrowingCases)
    func narrowing(narrowingCase: NarrowingCase) {
        #expect(narrowingCase.level.output(within: narrowingCase.appOutput) == narrowingCase.expected)
    }

    @Test("A quality gives the output of its level, and the high one the output itself")
    func qualities() {
        let appOutput = CameraFlowOutput()
        let levels = Self.custom
        #expect(CameraFlowQuality.high.output(within: appOutput, levels: levels) == appOutput)
        let medium = CameraFlowQuality.medium.output(within: appOutput, levels: levels)
        #expect(medium == CameraFlowOutput(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8)))
        let low = CameraFlowQuality.low.output(within: appOutput, levels: levels)
        #expect(low == CameraFlowOutput(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6)))
    }

    @Test("A level whose output is that of a quality above it is not offered")
    func notOffered() {
        var levels = Self.custom
        #expect(CameraFlowQuality.distinct(within: CameraFlowOutput(), levels: levels) == [.high, .medium, .low])
        levels.low = levels.medium
        #expect(CameraFlowQuality.distinct(within: CameraFlowOutput(), levels: levels) == [.high, .medium])
        #expect(CameraFlowQuality.low.offered(within: CameraFlowOutput(), levels: levels) == .medium)
        let small = CameraFlowOutput(size: .longSide(maximum: 800), format: .jpeg(quality: 0.5))
        #expect(CameraFlowQuality.distinct(within: small, levels: Self.custom) == [.high])
    }

    @Test(
        "The stricter of two sizes wins, and the original size only where neither has a limit",
        arguments: [
            (CameraFlowOutputSize.original, CameraFlowOutputSize.original, CameraFlowOutputSize.original),
            (.original, .longSide(maximum: 1000), .longSide(maximum: 1000)),
            (.longSide(maximum: 1000), .original, .longSide(maximum: 1000)),
            (.longSide(maximum: 2048), .longSide(maximum: 1000), .longSide(maximum: 1000)),
            (.longSide(maximum: 1000), .longSide(maximum: 2048), .longSide(maximum: 1000))
        ]
    )
    func narrowedSize(size: CameraFlowOutputSize, other: CameraFlowOutputSize, expected: CameraFlowOutputSize) {
        #expect(size.narrowed(by: other) == expected)
    }

    @Test("A smaller file at the photo's size is offered, and a level that changes nothing is not")
    func originalSize() {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .original, format: .jpeg(quality: 0.7))
        levels.validate()
        #expect(CameraFlowQuality.distinct(within: CameraFlowOutput(), levels: levels) == [.high, .medium, .low])
        levels.medium = CameraFlowQualityLevel(size: .original)
        #expect(CameraFlowQuality.medium.output(within: CameraFlowOutput(), levels: levels) == CameraFlowOutput())
        #expect(CameraFlowQuality.distinct(within: CameraFlowOutput(), levels: levels) == [.high, .low])
        #expect(CameraFlowQuality.medium.offered(within: CameraFlowOutput(), levels: levels) == .high)
    }

    @Test("A low level larger than the medium one is offered as it is")
    func lowAboveMedium() {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 1024))
        levels.low = CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.3))
        levels.validate()
        #expect(CameraFlowQuality.distinct(within: CameraFlowOutput(), levels: levels) == [.high, .medium, .low])
    }

    @Test("Levels a photo can meet pass the check of the configuration")
    func valid() {
        var configuration = CameraFlowConfiguration()
        configuration.settingsMemory = .off
        configuration.photoQualityLevels = Self.custom
        let smallest = CameraFlowOutputSize.longSide(maximum: 1)
        configuration.photoQualityLevels.low = CameraFlowQualityLevel(size: smallest, format: .heic(quality: 0))
        configuration.validate()
    }

    #if os(macOS)
    @Test("A level with a long side below one pixel stops the program")
    func invalidLongSide() async {
        await #expect(processExitsWith: .failure) {
            var configuration = CameraFlowConfiguration()
            configuration.settingsMemory = .off
            configuration.photoQualityLevels.medium.size = .longSide(maximum: 0)
            configuration.validate()
        }
    }

    @Test("A level with a compression quality outside 0...1 stops the program")
    func invalidCompressionQuality() async {
        await #expect(processExitsWith: .failure) {
            var configuration = CameraFlowConfiguration()
            configuration.settingsMemory = .off
            configuration.photoQualityLevels.low.format = .jpeg(quality: 1.5)
            configuration.validate()
        }
    }
    #endif
}
