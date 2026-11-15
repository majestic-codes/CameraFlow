//
//  LibraryPictureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The full picture for the photo library beside an output that changed the photo, which only a flow that saves
/// keeps.
@MainActor
@Suite("The full picture for the photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LibraryPictureTests {
    private static var reencodingOutput: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        return output
    }

    private func storedFileNames(of harness: FlowHarness) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: harness.files.directory.path).sorted()
    }

    @Test("A flow that never saves writes the output of a shot alone")
    func neverSaves() async throws {
        let harness = FlowHarness()
        let flow = harness.makeFlow(output: Self.reencodingOutput)
        await flow.camera.start()
        await flow.camera.capture()
        let photo = try #require(flow.photoSet.photos.first)
        #expect(photo.libraryFileURL == nil)
        #expect(try storedFileNames(of: harness) == [photo.fileURL.lastPathComponent])
        flow.photoSet.discard()
    }

    @Test("A flow that may save keeps the camera's photo beside the output")
    func saves() async throws {
        let harness = FlowHarness()
        let writer = FakePhotoLibraryWriter(authorization: .authorized)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let flow = harness.makeFlow(output: Self.reencodingOutput, librarySaving: saving)
        await flow.camera.start()
        await flow.camera.capture()
        let photo = try #require(flow.photoSet.photos.first)
        let libraryURL = try #require(photo.libraryFileURL)
        #expect(try storedFileNames(of: harness) == [photo.fileURL, libraryURL].map(\.lastPathComponent).sorted())
        flow.photoSet.discard()
    }
}
