//
//  FlowTestSupport.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CameraFlow

enum FlowTestSupport {

    /// A capture as the camera hands it over: a small photo file in the store, and a movie and a copy with the front
    /// camera's circle when asked for.
    static func makeCapture(
        in files: CaptureFileStore,
        withMovie: Bool = false,
        withDualCameraCopy: Bool = false
    ) throws -> CameraCapture {
        let identifier = UUID()
        let fileURL = try files.writePhoto(Data([1, 2, 3]), identifier: identifier, type: .jpeg)
        var movieURL: URL?
        if withMovie {
            let source = TestDirectory.current.appendingPathComponent(UUID().uuidString + ".mov")
            try Data([4]).write(to: source)
            movieURL = try files.moveMovie(from: source, identifier: identifier)
        }
        var dualCameraCopy: CameraFlowPhoto.File?
        if withDualCameraCopy {
            let url = files.directory.appendingPathComponent("\(identifier.uuidString)-dual-1.jpg")
            try Data([5, 6]).write(to: url)
            dualCameraCopy = CameraFlowPhoto.File(url: url, contentType: .jpeg)
        }
        return CameraCapture(
            id: identifier,
            fileURL: fileURL,
            libraryFileURL: nil,
            contentType: .jpeg,
            thumbnail: try makeImage(width: 1, height: 1),
            livePhotoMovieURL: movieURL,
            framedRegion: nil,
            dualCameraCopy: dualCameraCopy
        )
    }

    /// A small upright JPEG, wider than it is tall.
    static func makeJPEG() throws -> Data {
        let image = try makeImage(width: 40, height: 30)
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func makeImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        return try #require(context.makeImage())
    }

    static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Whether the ledger beside a directory of the package still enters it, under any run.
    static func isEntered(_ directory: URL) throws -> Bool {
        let runs = directory.deletingLastPathComponent().appendingPathComponent(".runs", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: runs.path)
        return names.contains { run in
            fileExists(runs.appendingPathComponent(run).appendingPathComponent(directory.lastPathComponent))
        }
    }

    /// A drawing of the engine that reads no data, told from another by its text.
    static func makeDrawing(_ text: String = "ink") throws -> MarkupDrawing {
        try MarkupDrawing(engine: .pencilKit, data: Data(text.utf8), canvasSize: CGSize(width: 400, height: 300))
    }

    /// Deletes the files of photos of a set the test took apart itself.
    static func discardFiles(of photos: [FlowPhoto]) throws {
        for url in photos.flatMap(\.fileURLs) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Deletes the files of photos the test received, as a receiver must.
    static func discardFiles(of photos: [CameraFlowPhoto]) throws {
        for url in photos.flatMap(\.fileURLs) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

extension PhotoSetModel {
    /// Whether a photo of the set was taken with the camera.
    var hasCameraPhotos: Bool {
        photos.contains { $0.source == .camera }
    }
}

/// Checks that no file of the photos is left on disk.
func expectDeleted(_ photos: [FlowPhoto], sourceLocation: SourceLocation = #_sourceLocation) {
    for url in photos.flatMap(\.fileURLs) {
        #expect(FlowTestSupport.fileExists(url) == false, sourceLocation: sourceLocation)
    }
}
