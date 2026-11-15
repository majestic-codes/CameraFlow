//
//  PhotoCapturePipelineLossTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A part of a photo the pipeline cannot write: the copy with the circle or the Live Photo movie is left out and
/// the photo is handed over without it, while a full disk still fails the shot.
@MainActor
@Suite("Pipeline: a part that cannot be written", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCapturePipelineLossTests {
    private let store = CaptureTestSupport.makeFileStore()

    private func storedFileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.directory.path).sorted()
    }

    private func dualCapture(frameData: Data) throws -> CapturedPhoto {
        let frame = CircleCameraFrame(imageData: frameData, isViewfinderMirrored: false, viewfinderQuarterTurns: 0)
        return CapturedPhoto(
            imageData: try DevicePhotoFixture.makeCameraFile(),
            encoding: .heif,
            livePhotoMovieURL: nil,
            circleCameraFrame: frame
        )
    }

    private func pipeline(output: CameraFlowOutput, keepsLibraryPicture: Bool) -> PhotoCapturePipeline {
        PhotoCapturePipeline(
            aspectRatio: .fourByThree,
            output: output,
            store: store,
            dualCameraCircle: DualCameraFixture.circleOnScreen,
            keepsLibraryPicture: keepsLibraryPicture
        )
    }

    private static var changedOutput: CameraFlowOutput {
        var output = CameraFlowOutput()
        output.size = .longSide(maximum: 128)
        return output
    }

    @Test("A circle frame that cannot be drawn hands the photo over without the copy, with the loss")
    func undrawableCircle() async throws {
        let photo = try dualCapture(frameData: Data("not a picture".utf8))
        let capture = try await pipeline(output: CameraFlowOutput(), keepsLibraryPicture: true).process(photo)
        #expect(capture.dualCameraCopy == nil)
        #expect(capture.libraryFileURL == nil)
        #expect(capture.losses == [.circleCameraFrame])
        #expect(try storedFileNames() == [capture.fileURL.lastPathComponent])
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("Under a changed output a failed copy leaves the camera's photo as the library's picture")
    func undrawableCircleKeepsLibraryPicture() async throws {
        let photo = try dualCapture(frameData: Data("not a picture".utf8))
        let capture = try await pipeline(output: Self.changedOutput, keepsLibraryPicture: true).process(photo)
        let libraryURL = try #require(capture.libraryFileURL)
        #expect(libraryURL.lastPathComponent.contains("-camera."))
        #expect(capture.dualCameraCopy == nil)
        #expect(capture.losses == [.circleCameraFrame])
        #expect(try storedFileNames() == [capture.fileURL, libraryURL].map(\.lastPathComponent).sorted())
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("In a flow that never saves a failed copy leaves the output alone")
    func undrawableCircleWithoutLibraryPicture() async throws {
        let photo = try dualCapture(frameData: Data("not a picture".utf8))
        let capture = try await pipeline(output: Self.changedOutput, keepsLibraryPicture: false).process(photo)
        #expect(capture.libraryFileURL == nil)
        #expect(capture.dualCameraCopy == nil)
        #expect(capture.losses == [.circleCameraFrame])
        #expect(try storedFileNames() == [capture.fileURL.lastPathComponent])
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A Live Photo movie that cannot be moved hands the still over, with the loss")
    func unmovableMovie() async throws {
        let missingMovie = TestDirectory.current.appendingPathComponent("missing.mov")
        let photo = CapturedPhoto(
            imageData: try DevicePhotoFixture.makeCameraFile(),
            encoding: .heif,
            livePhotoMovieURL: missingMovie
        )
        let capture = try await pipeline(output: CameraFlowOutput(), keepsLibraryPicture: true).process(photo)
        #expect(capture.livePhotoMovieURL == nil)
        #expect(capture.losses == [.livePhotoMovie])
        #expect(try storedFileNames() == [capture.fileURL.lastPathComponent])
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A full disk still fails the shot, any other failure of a part does not")
    func fullDiskStaysFatal() {
        #expect(throws: CameraServiceError.notEnoughStorage) {
            try PhotoCapturePipeline.rethrowIfOutOfStorage(CameraServiceError.notEnoughStorage)
        }
        #expect(throws: Never.self) {
            try PhotoCapturePipeline.rethrowIfOutOfStorage(CameraServiceError.cannotStore("Cannot move"))
            try PhotoCapturePipeline.rethrowIfOutOfStorage(OverlayCopyFailure.cannotEncode("No destination"))
        }
    }

    @Test("A complete capture reports no loss")
    func noLoss() async throws {
        let photo = try dualCapture(frameData: try DevicePhotoFixture.make())
        let capture = try await pipeline(output: CameraFlowOutput(), keepsLibraryPicture: true).process(photo)
        #expect(capture.dualCameraCopy != nil)
        #expect(capture.losses.isEmpty)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
