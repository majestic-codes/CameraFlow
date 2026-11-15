//
//  PhotoQualityOutputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@_spi(Testing) @testable import CameraFlow

/// The chosen quality in the files the app receives, checked on a 2560 x 1920 photo: from the camera, from the
/// photo library and as the copy with a drawing.
@MainActor
@Suite("Quality: the files the app receives", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoQualityOutputTests {
    // MARK: - Camera photos

    @Test("At the high quality the camera's file reaches the app byte for byte")
    func cameraHigh() async throws {
        let harness = await QualityHarness().started()
        let photo = try await harness.takeLargePhoto()
        #expect(try Data(contentsOf: photo.fileURL) == LargePhotoFixture.heic.get())
        #expect(photo.libraryFileURL == nil)
        harness.photoSet.discard()
    }

    @Test("Each lower quality gives a camera photo of 1920 pixels and a smaller file than the one above")
    func cameraLadder() async throws {
        let harness = await QualityHarness().started()
        var facts: [LargePhotoFixture.Facts] = []
        for quality in CameraFlowQuality.allCases {
            harness.settings.select(photoQuality: quality)
            let photo = try await harness.takeLargePhoto()
            facts.append(try LargePhotoFixture.facts(of: photo.fileURL))
        }
        #expect(facts.map(\.type) == [.heic, .heic, .heic])
        #expect(facts.map(\.width) == [2560, 1920, 1920])
        #expect(facts.map(\.height) == [1920, 1440, 1440])
        #expect(facts[1].byteCount < facts[0].byteCount)
        #expect(facts[2].byteCount < facts[1].byteCount)
        harness.photoSet.discard()
    }

    @Test("A reduced 16:9 photo is cropped first and then scaled to 1920 x 1080")
    func cameraSixteenByNine() async throws {
        var state = CameraFlowInitialState()
        state.aspectRatio.value = .sixteenByNine
        let harness = await QualityHarness(setting: CameraFlowSetting(.medium), initialState: state).started()
        let photo = try await harness.takeLargePhoto()
        let facts = try LargePhotoFixture.facts(of: photo.fileURL)
        #expect(facts.width == 1920)
        #expect(facts.height == 1080)
        harness.photoSet.discard()
    }

    @Test("A quality the app fixed applies to every photo without a choice")
    func cameraFixed() async throws {
        let harness = await QualityHarness(setting: .fixed(.medium)).started()
        let photo = try await harness.takeLargePhoto()
        let facts = try LargePhotoFixture.facts(of: photo.fileURL)
        #expect(facts.width == 1920)
        harness.photoSet.discard()
    }

    @Test("Inside a JPEG output of the app every quality gives a JPEG, the low one at most at 0.5")
    func cameraWithinJPEGOutput() async throws {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        let harness = await QualityHarness(output: output).started()
        var facts: [LargePhotoFixture.Facts] = []
        for quality in CameraFlowQuality.allCases {
            harness.settings.select(photoQuality: quality)
            let photo = try await harness.takeLargePhoto()
            facts.append(try LargePhotoFixture.facts(of: photo.fileURL))
        }
        #expect(facts.map(\.type) == [.jpeg, .jpeg, .jpeg])
        #expect(facts.map(\.width) == [2560, 1920, 1920])
        #expect(facts[1].byteCount < facts[0].byteCount)
        #expect(facts[2].byteCount < facts[1].byteCount)
        harness.photoSet.discard()
    }

    @Test("No quality gives a photo larger than the size the app set")
    func cameraWithinSmallerSize() async throws {
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 1000)
        let harness = await QualityHarness(output: output).started()
        #expect(harness.settings.offeredPhotoQualities == [.high, .low])
        for quality in [CameraFlowQuality.high, .low] {
            harness.settings.select(photoQuality: quality)
            let photo = try await harness.takeLargePhoto()
            let facts = try LargePhotoFixture.facts(of: photo.fileURL)
            #expect(facts.width == 1000)
            #expect(facts.height == 750)
        }
        harness.photoSet.discard()
    }

    // MARK: - The levels of the app

    private static var customLevels: CameraFlowQualityLevels {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8))
        levels.low = CameraFlowQualityLevel(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6))
        return levels
    }

    @Test("Levels the app set give camera photos of their size in their format")
    func cameraCustomLevels() async throws {
        let harness = QualityHarness(levels: Self.customLevels)
        await harness.camera.start()
        var facts: [LargePhotoFixture.Facts] = []
        for quality in CameraFlowQuality.allCases {
            harness.settings.select(photoQuality: quality)
            let photo = try await harness.takeLargePhoto()
            facts.append(try LargePhotoFixture.facts(of: photo.fileURL))
        }
        #expect(facts.map(\.type) == [.heic, .jpeg, .jpeg])
        #expect(facts.map(\.width) == [2560, 2048, 1280])
        #expect(facts.map(\.height) == [1920, 1536, 960])
        #expect(facts[2].byteCount < facts[1].byteCount)
        harness.photoSet.discard()
    }

    @Test("Levels the app set apply to a pick from the library and to the copy with a drawing")
    func libraryCustomLevels() async throws {
        let harness = QualityHarness(setting: CameraFlowSetting(.low), levels: Self.customLevels)
        await harness.camera.start()
        let pick = try await harness.pickLargePhoto()
        let facts = try LargePhotoFixture.facts(of: pick.fileURL)
        #expect(facts.type == .jpeg)
        #expect(facts.width == 1280)
        #expect(facts.height == 960)
        harness.photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: pick.id)
        await harness.photoSet.handOver()
        let photos = try #require(harness.outcome.handedOver.first)
        let copyURL = try #require(photos.first?.markedUp?.url)
        let copy = try LargePhotoFixture.facts(of: copyURL)
        #expect(copy.type == .jpeg)
        #expect(copy.width == 1280)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("Inside a HEIC output of the app a level with a JPEG format gives a HEIC of the level's size")
    func customLevelsWithinHEICOutput() async throws {
        var output = CameraFlowOutput()
        output.format = .heic(quality: 0.9)
        let harness = QualityHarness(setting: CameraFlowSetting(.medium), output: output, levels: Self.customLevels)
        await harness.camera.start()
        #expect(harness.settings.output.format == .heic(quality: 0.8))
        let photo = try await harness.takeLargePhoto()
        let facts = try LargePhotoFixture.facts(of: photo.fileURL)
        #expect(facts.type == .heic)
        #expect(facts.width == 2048)
        harness.photoSet.discard()
    }

    // MARK: - Library picks

    @Test("A pick from the library is brought to the quality chosen when it is picked")
    func libraryLadder() async throws {
        let harness = await QualityHarness().started()
        var facts: [LargePhotoFixture.Facts] = []
        for quality in CameraFlowQuality.allCases {
            harness.settings.select(photoQuality: quality)
            let pick = try await harness.pickLargePhoto()
            facts.append(try LargePhotoFixture.facts(of: pick.fileURL))
        }
        #expect(facts.map(\.type) == [.jpeg, .jpeg, .heic])
        #expect(facts.map(\.width) == [2560, 1920, 1920])
        #expect(facts.map(\.height) == [1920, 1440, 1440])
        #expect(facts[0].byteCount == (try LargePhotoFixture.jpeg.get()).count)
        #expect(facts[1].byteCount < facts[0].byteCount)
        #expect(facts[2].byteCount < facts[1].byteCount)
        harness.photoSet.discard()
    }

    // MARK: - Copies with a drawing

    @Test("The copy with a drawing has the quality its photo was taken with, whatever is chosen at the hand-over")
    func markedUpCopies() async throws {
        let harness = await QualityHarness().started()
        let high = try await harness.takeLargePhoto()
        harness.settings.select(photoQuality: .low)
        let low = try await harness.takeLargePhoto()
        harness.settings.select(photoQuality: .medium)
        let drawing = try FlowTestSupport.makeDrawing()
        harness.photoSet.setDrawing(drawing, ofPhoto: high.id)
        harness.photoSet.setDrawing(drawing, ofPhoto: low.id)
        await harness.photoSet.handOver()
        let photos = try #require(harness.outcome.handedOver.first)
        let highCopyURL = try #require(photos.first?.markedUp?.url)
        let highCopy = try LargePhotoFixture.facts(of: highCopyURL)
        let lowCopyURL = try #require(photos.last?.markedUp?.url)
        let lowCopy = try LargePhotoFixture.facts(of: lowCopyURL)
        #expect(highCopy.width == 2560)
        #expect(lowCopy.width == 1920)
        #expect(lowCopy.type == .heic)
        try FlowTestSupport.discardFiles(of: photos)
    }
}
