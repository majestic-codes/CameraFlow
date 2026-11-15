//
//  CameraFlowLibraryOutputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The output of the camera photos and of the picks from the photo library, each on its own, checked on a
/// 2560 x 1920 photo.
@MainActor
@Suite("Output: camera photos and library picks apart", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowLibraryOutputTests {
    private static var standardJPEG: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.size = .standard
        output.format = .jpeg(quality: 0.7)
        return output
    }

    private func makeStartedHarness(
        setting: CameraFlowSetting<CameraFlowQuality> = .fixed(.high),
        output: CameraFlowOutput = CameraFlowOutput(),
        libraryOutput: CameraFlowLibraryOutput
    ) async -> QualityHarness {
        await QualityHarness(setting: setting, output: output, libraryOutput: libraryOutput).started()
    }

    @Test("By default a pick shares the output of the camera photos")
    func sameAsCameraByDefault() async throws {
        #expect(CameraFlowConfiguration().libraryOutput == .sameAsCamera)
        let harness = await makeStartedHarness(output: Self.standardJPEG, libraryOutput: .sameAsCamera)
        let cameraPhoto = try await harness.takeLargePhoto()
        let camera = try LargePhotoFixture.facts(of: cameraPhoto.fileURL)
        let pickedPhoto = try await harness.pickLargePhoto()
        let pick = try LargePhotoFixture.facts(of: pickedPhoto.fileURL)
        #expect(camera.width == 1920)
        #expect(pick.width == 1920)
        #expect(camera.type == .jpeg)
        #expect(pick.type == .jpeg)
        harness.photoSet.discard()
    }

    @Test("An output for the camera only leaves the picks as the library gave them")
    func cameraOnly() async throws {
        let harness = await makeStartedHarness(output: Self.standardJPEG, libraryOutput: .separate(CameraFlowOutput()))
        let cameraPhoto = try await harness.takeLargePhoto()
        let camera = try LargePhotoFixture.facts(of: cameraPhoto.fileURL)
        let pick = try await harness.pickLargePhoto()
        #expect(camera.width == 1920)
        #expect(try Data(contentsOf: pick.fileURL) == LargePhotoFixture.jpeg.get())
        harness.photoSet.discard()
    }

    @Test("An output for the picks only leaves the camera photos as the camera gave them")
    func libraryOnly() async throws {
        let harness = await makeStartedHarness(libraryOutput: .separate(Self.standardJPEG))
        let camera = try await harness.takeLargePhoto()
        let pickedPhoto = try await harness.pickLargePhoto()
        let pick = try LargePhotoFixture.facts(of: pickedPhoto.fileURL)
        #expect(try Data(contentsOf: camera.fileURL) == LargePhotoFixture.heic.get())
        #expect(pick.width == 1920)
        #expect(pick.type == .jpeg)
        harness.photoSet.discard()
    }

    @Test("The user's quality narrows the camera photos and leaves a separate output of the picks as it is")
    func qualityNarrowsCameraOnly() async throws {
        var library = CameraFlowOutput()
        library.format = .heic(quality: 0.8)
        let harness = await makeStartedHarness(setting: CameraFlowSetting(.high), libraryOutput: .separate(library))
        harness.settings.select(photoQuality: .low)
        let cameraPhoto = try await harness.takeLargePhoto()
        let camera = try LargePhotoFixture.facts(of: cameraPhoto.fileURL)
        let pickedPhoto = try await harness.pickLargePhoto()
        let pick = try LargePhotoFixture.facts(of: pickedPhoto.fileURL)
        #expect(camera.width == 1920)
        #expect(pick.width == 2560)
        #expect(pick.type == .heic)
        harness.photoSet.discard()
    }

    @Test("Under the camera's output the user's quality narrows the picks as well")
    func qualityNarrowsSharedPicks() async throws {
        let harness = await makeStartedHarness(setting: CameraFlowSetting(.high), libraryOutput: .sameAsCamera)
        harness.settings.select(photoQuality: .medium)
        let pickedPhoto = try await harness.pickLargePhoto()
        let pick = try LargePhotoFixture.facts(of: pickedPhoto.fileURL)
        #expect(pick.width == 1920)
        harness.photoSet.discard()
    }

    @Test("The compression of a separate output is the one the picks are encoded at")
    func separateCompression() async throws {
        var small = CameraFlowOutput()
        small.format = .jpeg(quality: 0.2)
        var large = CameraFlowOutput()
        large.format = .jpeg(quality: 0.95)
        let lowHarness = await makeStartedHarness(libraryOutput: .separate(small))
        let highHarness = await makeStartedHarness(libraryOutput: .separate(large))
        let lowPick = try await lowHarness.pickLargePhoto()
        let low = try LargePhotoFixture.facts(of: lowPick.fileURL)
        let highPick = try await highHarness.pickLargePhoto()
        let high = try LargePhotoFixture.facts(of: highPick.fileURL)
        #expect(low.width == high.width)
        #expect(low.byteCount < high.byteCount)
        lowHarness.photoSet.discard()
        highHarness.photoSet.discard()
    }
}
