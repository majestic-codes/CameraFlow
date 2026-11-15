//
//  PhotoScreenImageTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

@Suite("Photo for the screen", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoScreenImageTests {
    let directory = TestDirectory.current.appendingPathComponent(UUID().uuidString)

    @Test("The picture is upright whatever orientation the file stores", arguments: OrientedPhotoFixture.orientations)
    func upright(orientation: Int) async throws {
        let url = try OrientedPhotoFixture.makeFile(orientation: orientation, type: .jpeg, in: directory)
        defer { CaptureFileStore.discard(url) }
        let image = try await PhotoScreenImage.decode(url: url, maximumPixelSize: 64)
        #expect(image.width == 64)
        #expect(image.height == 48)
        let grid = try PixelGrid(image)
        for quarter in OrientedPhotoFixture.Quarter.allCases {
            let spot = quarter.spot
            let pixel = try grid[spot.column / 2, spot.row / 2]
            #expect(pixel.isClose(to: quarter.color), "\(quarter) at orientation \(orientation)")
        }
    }

    @Test("The picture is scaled from the full image, not taken from the thumbnail the file embeds")
    func ignoresEmbeddedThumbnail() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("embedded.jpeg")
        defer { CaptureFileStore.discard(url) }
        let image = try FlowTestSupport.makeImage(width: 1200, height: 900)
        let type = UTType.jpeg.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil))
        let options = [kCGImageDestinationEmbedThumbnail: true] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        try #require(CGImageDestinationFinalize(destination))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let lookup: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 600
        ]
        let embedded = try #require(CGImageSourceCreateThumbnailAtIndex(source, 0, lookup as CFDictionary))
        try #require(embedded.width < 600, "The fixture embeds no thumbnail")
        let decoded = try await PhotoScreenImage.decode(url: url, maximumPixelSize: 600)
        #expect(decoded.width == 600)
        #expect(decoded.height == 450)
    }

    @Test("A photo smaller than the screen keeps its size")
    func smallPhoto() async throws {
        let url = try OrientedPhotoFixture.makeFile(orientation: 1, type: .jpeg, in: directory)
        defer { CaptureFileStore.discard(url) }
        let image = try await PhotoScreenImage.decode(url: url, maximumPixelSize: 4096)
        #expect(image.width == OrientedPhotoFixture.uprightWidth)
        #expect(image.height == OrientedPhotoFixture.uprightHeight)
    }

    @Test("A file that is no image is refused")
    func noImage() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("text.jpeg")
        defer { CaptureFileStore.discard(url) }
        try Data("not a photo".utf8).write(to: url)
        await #expect(throws: CameraServiceError.noImageData) {
            try await PhotoScreenImage.decode(url: url, maximumPixelSize: 64)
        }
    }
}
