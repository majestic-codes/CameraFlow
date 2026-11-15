//
//  CameraFlowPhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
import UniformTypeIdentifiers
import CameraFlow

/// A photo an app builds for its own tests and previews, through the public initializer alone.
@Suite("A photo an app builds itself")
struct CameraFlowPhotoTests {
    private static let originalURL = URL(filePath: "/photos/original.dng")
    private static let copyURL = URL(filePath: "/photos/copy.heic")

    /// A one-pixel picture, nil where Core Graphics cannot make one.
    private static func makeThumbnail() -> CGImage? {
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context?.makeImage()
    }

    @Test("A photo takes the values it is given, and the optional ones are absent by default")
    func defaults() throws {
        let thumbnail = try #require(Self.makeThumbnail())
        let original = CameraFlowPhoto.File(url: Self.originalURL, contentType: .jpeg)
        let photo = CameraFlowPhoto(source: .photoLibrary, original: original, thumbnail: thumbnail)
        #expect(photo.source == .photoLibrary)
        #expect(photo.original.url == Self.originalURL)
        #expect(photo.original.contentType == .jpeg)
        #expect(photo.livePhotoMovieURL == nil)
        #expect(photo.markedUp == nil)
        #expect(photo.thumbnail === thumbnail)
        #expect(photo.framedRegion == nil)
        #expect(photo.photoLibrarySave == nil)
        #expect(photo.result == original)
        let copy = CameraFlowPhoto.File(url: Self.copyURL, contentType: .heic)
        let other = CameraFlowPhoto(source: .camera, original: copy, thumbnail: thumbnail)
        #expect(other.id != photo.id)
    }

    @Test("A photo with a copy has the copy as its result, with the copy's type")
    func copy() throws {
        let thumbnail = try #require(Self.makeThumbnail())
        let identifier = UUID()
        let framedRegion = CGRect(x: 0, y: 0.125, width: 1, height: 0.75)
        let rawType = UTType(importedAs: "com.adobe.raw-image")
        let original = CameraFlowPhoto.File(url: Self.originalURL, contentType: rawType)
        let copy = CameraFlowPhoto.File(url: Self.copyURL, contentType: .heic)
        let photo = CameraFlowPhoto(
            id: identifier,
            source: .camera,
            original: original,
            markedUp: copy,
            thumbnail: thumbnail,
            framedRegion: framedRegion,
            photoLibrarySave: .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))
        )
        #expect(photo.id == identifier)
        #expect(photo.original == original)
        #expect(photo.markedUp == copy)
        #expect(photo.result.url == Self.copyURL)
        #expect(photo.result.contentType == .heic)
        #expect(photo.framedRegion == framedRegion)
        #expect(photo.photoLibrarySave == .saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")))
    }

    @Test("A saved photo's asset misses no drawing by default, and assets are one when both values match")
    func asset() {
        let asset = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")
        #expect(asset.localIdentifier == "asset-1")
        #expect(asset.isMissingDrawing == false)
        let missing = CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1", isMissingDrawing: true)
        #expect(missing.isMissingDrawing)
        #expect(asset != missing)
        #expect(asset == CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1", isMissingDrawing: false))
        #expect(Set([asset, missing, asset]).count == 2)
        #expect(CameraFlowPhotoLibrarySave.saved(asset) != .saved(missing))
    }

    @Test("A file is its place and its type: two files are one when both match")
    func file() {
        let file = CameraFlowPhoto.File(url: Self.copyURL, contentType: .heic)
        #expect(file.url == Self.copyURL)
        #expect(file.contentType == .heic)
        #expect(file == CameraFlowPhoto.File(url: Self.copyURL, contentType: .heic))
        #expect(file != CameraFlowPhoto.File(url: Self.copyURL, contentType: .jpeg))
        #expect(file != CameraFlowPhoto.File(url: Self.originalURL, contentType: .heic))
        #expect(Set([file, file, CameraFlowPhoto.File(url: Self.originalURL, contentType: .heic)]).count == 2)
    }
}
