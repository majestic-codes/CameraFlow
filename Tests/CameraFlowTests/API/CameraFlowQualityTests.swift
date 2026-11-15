//
//  CameraFlowQualityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Quality: what the user's choice makes of the app's output")
struct CameraFlowQualityTests {
    /// An output of the app, a quality and the output the two make.
    struct NarrowingCase: Sendable, CustomTestStringConvertible {
        let name: String
        let appOutput: CameraFlowOutput
        let quality: CameraFlowQuality
        let expected: CameraFlowOutput

        var testDescription: String {
            name
        }
    }

    /// An output of the app that encodes every photo again: a JPEG at most 3000 pixels long, without its metadata.
    static let reencodingOutput = CameraFlowOutput(
        size: .longSide(maximum: 3000),
        format: .jpeg(quality: 0.8),
        metadata: .stripped
    )

    static let narrowingCases = [
        NarrowingCase(
            name: "high, default output",
            appOutput: CameraFlowOutput(),
            quality: .high,
            expected: CameraFlowOutput()
        ),
        NarrowingCase(
            name: "medium, default output",
            appOutput: CameraFlowOutput(),
            quality: .medium,
            expected: CameraFlowOutput(size: .longSide(maximum: 1920))
        ),
        NarrowingCase(
            name: "low, default output",
            appOutput: CameraFlowOutput(),
            quality: .low,
            expected: CameraFlowOutput(size: .longSide(maximum: 1920), format: .heic(quality: 0.5))
        ),
        NarrowingCase(
            name: "high, a re-encoding output",
            appOutput: reencodingOutput,
            quality: .high,
            expected: reencodingOutput
        ),
        NarrowingCase(
            name: "medium keeps the format and the metadata of the output",
            appOutput: reencodingOutput,
            quality: .medium,
            expected: CameraFlowOutput(size: .longSide(maximum: 1920), format: .jpeg(quality: 0.8), metadata: .stripped)
        ),
        NarrowingCase(
            name: "low keeps the type of the output's format",
            appOutput: CameraFlowOutput(format: .jpeg(quality: 0.8)),
            quality: .low,
            expected: CameraFlowOutput(size: .longSide(maximum: 1920), format: .jpeg(quality: 0.5))
        ),
        NarrowingCase(
            name: "low never compresses less than the output",
            appOutput: CameraFlowOutput(format: .heic(quality: 0.3)),
            quality: .low,
            expected: CameraFlowOutput(size: .longSide(maximum: 1920), format: .heic(quality: 0.3))
        ),
        NarrowingCase(
            name: "medium never exceeds a smaller size of the output",
            appOutput: CameraFlowOutput(size: .longSide(maximum: 1000)),
            quality: .medium,
            expected: CameraFlowOutput(size: .longSide(maximum: 1000))
        ),
        NarrowingCase(
            name: "low never exceeds a smaller size of the output",
            appOutput: CameraFlowOutput(size: .longSide(maximum: 1000)),
            quality: .low,
            expected: CameraFlowOutput(size: .longSide(maximum: 1000), format: .heic(quality: 0.5))
        )
    ]

    @Test("A quality narrows the output of the app", arguments: narrowingCases)
    func narrowing(narrowingCase: NarrowingCase) {
        #expect(narrowingCase.quality.output(within: narrowingCase.appOutput) == narrowingCase.expected)
    }

    static let appOutputs = [
        CameraFlowOutput(),
        CameraFlowOutput(size: .standard),
        CameraFlowOutput(size: .longSide(maximum: 640), format: .jpeg(quality: 0.2), metadata: .stripped),
        CameraFlowOutput(size: .longSide(maximum: 4032), format: .heic(quality: 0.9)),
        CameraFlowOutput(format: .jpeg(quality: 0.5))
    ]

    @Test(
        "No quality gives a larger or a less compressed photo than the output",
        arguments: appOutputs, CameraFlowQuality.allCases
    )
    func neverExceeds(appOutput: CameraFlowOutput, quality: CameraFlowQuality) {
        let narrowed = quality.output(within: appOutput)
        #expect(narrowed.size.maximumLongSide ?? .max <= appOutput.size.maximumLongSide ?? .max)
        #expect(narrowed.format.compressionQuality ?? 1 <= appOutput.format.compressionQuality ?? 1)
        #expect(narrowed.metadata == appOutput.metadata)
    }

    @Test("Each quality gives no more than the one above it", arguments: appOutputs)
    func ordered(appOutput: CameraFlowOutput) {
        let outputs = CameraFlowQuality.allCases.map { $0.output(within: appOutput) }
        for (better, worse) in zip(outputs, outputs.dropFirst()) {
            #expect(worse.size.maximumLongSide ?? .max <= better.size.maximumLongSide ?? .max)
            #expect(worse.format.compressionQuality ?? 1 <= better.format.compressionQuality ?? 1)
        }
    }

    @Test(
        "Only the qualities that give less than every one above them are offered",
        arguments: [
            (CameraFlowOutput(), [CameraFlowQuality.high, .medium, .low]),
            (CameraFlowOutput(size: .longSide(maximum: 4032)), [.high, .medium, .low]),
            (CameraFlowOutput(size: .standard), [.high, .low]),
            (CameraFlowOutput(size: .longSide(maximum: 800)), [.high, .low]),
            (CameraFlowOutput(format: .jpeg(quality: 0.8)), [.high, .medium, .low]),
            (CameraFlowOutput(format: .jpeg(quality: 0.4)), [.high, .medium]),
            (CameraFlowOutput(size: .standard, format: .heic(quality: 0.5)), [.high]),
            (CameraFlowOutput(size: .longSide(maximum: 800), format: .jpeg(quality: 0.3), metadata: .stripped), [.high])
        ]
    )
    func distinct(appOutput: CameraFlowOutput, expected: [CameraFlowQuality]) {
        #expect(CameraFlowQuality.distinct(within: appOutput) == expected)
    }

    @Test("A quality that is not offered stands for the best one with the same output")
    func offeredInPlace() {
        let standard = CameraFlowOutput(size: .standard)
        #expect(CameraFlowQuality.medium.offered(within: standard) == .high)
        #expect(CameraFlowQuality.low.offered(within: standard) == .low)
        let compressed = CameraFlowOutput(format: .jpeg(quality: 0.4))
        #expect(CameraFlowQuality.low.offered(within: compressed) == .medium)
        #expect(CameraFlowQuality.medium.offered(within: CameraFlowOutput()) == .medium)
    }

    @Test(
        "The high quality has none above it, so it stands for itself inside any output",
        arguments: [
            CameraFlowOutput(),
            CameraFlowOutput(size: .standard),
            CameraFlowOutput(size: .standard, format: .heic(quality: 0.5))
        ]
    )
    func highOfferedAsItself(appOutput: CameraFlowOutput) {
        #expect(CameraFlowQuality.high.offered(within: appOutput) == .high)
    }

    @Test("The qualities are stored by the names of their cases")
    func rawValues() {
        #expect(CameraFlowQuality.allCases.map(\.rawValue) == ["high", "medium", "low"])
    }

    @Test("The default flow fixes the high quality, so nothing is offered and no file is touched")
    func defaultConfiguration() {
        let configuration = CameraFlowConfiguration()
        #expect(configuration.photoQuality == .fixed(.high))
        #expect(configuration.photoQuality.value.output(within: configuration.output) == CameraFlowOutput())
    }

    @Test("The chosen quality is kept in the preferences by name, and an older value decodes without one")
    func preferences() throws {
        var preferences = CameraFlowPreferences()
        preferences.photoQuality = .low
        let data = try JSONEncoder().encode(preferences)
        #expect(try #require(String(data: data, encoding: .utf8)) == #"{"photoQuality":"low"}"#)
        #expect(try JSONDecoder().decode(CameraFlowPreferences.self, from: data) == preferences)
        let older = Data(#"{"isPhotoLibrarySavingEnabled":true}"#.utf8)
        #expect(try JSONDecoder().decode(CameraFlowPreferences.self, from: older).photoQuality == nil)
    }
}
