//
//  PhotoCapturePipelineTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("The capture pipeline: the file it makes of a delivered photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCapturePipelineTests {

    @Test(
        "A photo that needs no crop is handed over byte for byte",
        arguments: [
            (CameraFlowAspectRatio.fourByThree, PhotoCaptureEncoding.heif, false),
            (.sixteenByNine, .appleProRAW, true),
            (.square, .appleProRAW, true)
        ]
    )
    func untouched(
        aspectRatio: CameraFlowAspectRatio,
        encoding: PhotoCaptureEncoding,
        hasFramedRegion: Bool
    ) async throws {
        let original = try DevicePhotoFixture.make()
        let photo = CapturedPhoto(imageData: original, encoding: encoding, livePhotoMovieURL: nil)
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = PhotoCapturePipeline(aspectRatio: aspectRatio, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(photo)
        #expect(try Data(contentsOf: capture.fileURL) == original)
        #expect((capture.framedRegion != nil) == hasFramedRegion)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("The framed region of an uncropped 16:9 RAW is the centred band of the upright photo")
    func framedRegion() async throws {
        let photo = CapturedPhoto(
            imageData: try DevicePhotoFixture.make(),
            encoding: .appleProRAW,
            livePhotoMovieURL: nil
        )
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = PhotoCapturePipeline(aspectRatio: .sixteenByNine, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(photo)
        // Upright 192 x 256: a 16:9 portrait band is 144 wide, 24 pixels in from each side.
        #expect(capture.framedRegion == CGRect(x: 24.0 / 192, y: 0, width: 144.0 / 192, height: 1))
        #expect(try capture.uprightPixelSize() == CGSize(width: 192, height: 256))
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A capture is a HEIF file in the session directory with its size and thumbnail")
    func captureFields() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let photo = CapturedPhoto(
            imageData: try DevicePhotoFixture.make(),
            encoding: .heif,
            livePhotoMovieURL: nil
        )
        let pipeline = PhotoCapturePipeline(aspectRatio: .square, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(photo)
        #expect(capture.fileURL.deletingLastPathComponent() == store.directory)
        #expect(capture.fileURL.lastPathComponent == "\(capture.id.uuidString).heic")
        #expect(capture.contentType == .heic)
        #expect(try capture.uprightPixelSize() == CGSize(width: 192, height: 192))
        #expect(max(capture.thumbnail.width, capture.thumbnail.height) <= CameraCapture.thumbnailMaximumPixelSize)
        #expect(capture.framedRegion == nil)
        #expect(capture.livePhotoMovieURL == nil)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
