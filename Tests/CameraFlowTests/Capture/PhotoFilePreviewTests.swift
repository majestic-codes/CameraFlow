//
//  PhotoFilePreviewTests.swift
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

@Suite("Photo file preview", .temporaryDirectory)
struct PhotoFilePreviewTests {
    let directory = TestDirectory.current.appendingPathComponent(UUID().uuidString)

    @Test("The thumbnail comes from the image, not from the thumbnail the file embeds")
    func thumbnailFromImage() throws {
        let url = try StaleThumbnailFixture.makeFile(in: directory)
        defer { CaptureFileStore.discard(url) }
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let lookup: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 300
        ]
        let embedded = try #require(CGImageSourceCreateThumbnailAtIndex(source, 0, lookup as CFDictionary))
        let embeddedPixel = try PixelGrid(embedded)[embedded.width / 2, embedded.height / 2]
        try #require(embeddedPixel.isClose(to: StaleThumbnailFixture.thumbnailColor), "The fixture embeds no thumbnail")
        let preview = try PhotoFilePreview(url: url, maximumPixelSize: 300)
        #expect(preview.thumbnail.width == 300)
        let pixel = try PixelGrid(preview.thumbnail)[preview.thumbnail.width / 2, preview.thumbnail.height / 2]
        #expect(pixel.isClose(to: StaleThumbnailFixture.imageColor))
    }
}
