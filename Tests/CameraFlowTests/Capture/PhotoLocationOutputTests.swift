//
//  PhotoLocationOutputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreLocation
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

/// The place a photo was taken in every file made from it and in what goes to the photo library. The place is in
/// the southern hemisphere, which the camera fixture is not, so a GPS reference "S" is the flow's.
@Suite("The location in every output of a photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLocationOutputTests {
    private static let place = LocationFixture.location(latitude: -33.86, longitude: 151.21)
    private let store = CaptureTestSupport.makeFileStore()

    /// An output that changes the camera's file, by its name.
    struct ChangingOutput: Sendable, CustomTestStringConvertible {
        let name: String
        let output: CameraFlowOutput

        var testDescription: String {
            name
        }

        static let all: [Self] = [
            Self(name: "JPEG", output: makeOutput(format: .jpeg(quality: 0.8))),
            Self(name: "HEIC", output: makeOutput(format: .heic(quality: 0.5))),
            Self(name: "scaled", output: makeOutput(size: .longSide(maximum: 100))),
            Self(
                name: "low quality level",
                output: makeOutput(size: .longSide(maximum: 64), format: .heic(quality: 0.5))
            )
        ]
    }

    static func makeOutput(
        size: CameraFlowOutputSize = .original,
        format: CameraFlowOutputFormat = .original,
        metadata: CameraFlowOutputMetadata = .kept
    ) -> CameraFlowOutput {
        var output = CameraFlowOutput()
        output.size = size
        output.format = format
        output.metadata = metadata
        return output
    }

    private func process(
        output: CameraFlowOutput,
        encoding: PhotoCaptureEncoding = .heif
    ) async throws -> CameraCapture {
        let photo = CapturedPhoto(
            imageData: try DevicePhotoFixture.makeCameraFile(),
            encoding: encoding,
            livePhotoMovieURL: nil,
            location: Self.place
        )
        let pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: output, store: store)
        return try await pipeline.process(photo)
    }

    private func latitudeReference(of url: URL) throws -> String? {
        let properties = try ImageFile.properties(of: url)
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        return gps?[kCGImagePropertyGPSLatitudeRef] as? String
    }

    @Test(
        "An output that encodes the photo again keeps the place, and so does the camera's file beside it",
        arguments: ChangingOutput.all
    )
    func encodedAgain(changing: ChangingOutput) async throws {
        let capture = try await process(output: changing.output)
        #expect(try latitudeReference(of: capture.fileURL) == "S")
        let libraryURL = try #require(capture.libraryFileURL)
        #expect(try latitudeReference(of: libraryURL) == "S")
        #expect(capture.location === Self.place)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A stripped output has no place, the camera's file for the library keeps it")
    func stripped() async throws {
        let capture = try await process(output: Self.makeOutput(metadata: .stripped))
        let properties = try ImageFile.properties(of: capture.fileURL)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let libraryURL = try #require(capture.libraryFileURL)
        #expect(try latitudeReference(of: libraryURL) == "S")
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A RAW photo has no place in its file, but carries it for the photo library")
    func raw() async throws {
        let capture = try await process(output: CameraFlowOutput(), encoding: .appleProRAW)
        #expect(try latitudeReference(of: capture.fileURL) != "S")
        #expect(capture.location === Self.place)
        let entry = FlowPhoto(capture: capture).libraryEntry(markedUpFileURL: nil)
        #expect(entry.location === Self.place)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("The copy with a drawing and the edit the library gets keep the place")
    func markedUp() async throws {
        let capture = try await process(output: CameraFlowOutput())
        let copyURL = try await OverlayPhotoWriter.writeCopy(
            of: capture.fileURL,
            into: store.directory,
            label: "markup",
            output: CameraFlowOutput()
        ) { _, _ in }
        #expect(try latitudeReference(of: copyURL) == "S")
        let editDirectory = store.directory.appendingPathComponent("Edits", isDirectory: true)
        try FileManager.default.createDirectory(at: editDirectory, withIntermediateDirectories: true)
        let editURL = try PhotoLibraryEditFile.write(copyURL, into: editDirectory)
        #expect(try latitudeReference(of: editURL) == "S")
        let entry = FlowPhoto(capture: capture).libraryEntry(markedUpFileURL: copyURL)
        #expect(entry.location === Self.place)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
