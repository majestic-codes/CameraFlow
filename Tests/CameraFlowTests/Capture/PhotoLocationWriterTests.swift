//
//  PhotoLocationWriterTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Photo location writer", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoLocationWriterTests {
    static var gps: [CFString: Any] {
        let location = LocationFixture.location(latitude: -33.86, longitude: 151.21)
        return PhotoLocationMetadata.gpsDictionary(for: location)
    }

    @Test("The GPS dictionary is added and every other property of the camera's file stays", arguments: [8, 16])
    func keepsEverything(bitsPerComponent: Int) throws {
        let original = try DevicePhotoFixture.makeCameraFile(bitsPerComponent: bitsPerComponent)
        let outcome = PhotoLocationWriter.addingGPS(Self.gps, to: original)
        guard case let .located(located) = outcome else {
            Issue.record("The fixture got no location: \(outcome)")
            return
        }
        let originalProperties = try DevicePhotoFixture.properties(of: original)
        var locatedProperties = try DevicePhotoFixture.properties(of: located)
        let gps = try #require(locatedProperties.removeValue(forKey: kCGImagePropertyGPSDictionary) as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        #expect(gps[kCGImagePropertyGPSDateStamp] as? String == "2026:11:05")
        let makerApple = try #require(originalProperties[kCGImagePropertyMakerAppleDictionary] as? [String: Any])
        #expect(makerApple.count >= 10)
        let exif = try #require(originalProperties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifBrightnessValue] != nil)
        for (key, value) in originalProperties {
            let locatedValue = try #require(locatedProperties[key], "\(key) is lost")
            let original = try #require(value as? AnyHashable)
            #expect(locatedValue as? AnyHashable == original, "\(key) changed")
        }
        #expect(try DevicePhotoFixture.gainMapData(of: located) == DevicePhotoFixture.gainMapData(of: original))
        #expect(try Self.pixels(of: located) == Self.pixels(of: original))
    }

    @Test("A photo with a location keeps every key through the pipeline, cropped or not", arguments: allRatios)
    func throughPipeline(aspectRatio: CameraFlowAspectRatio) async throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let photo = CapturedPhoto(
            imageData: original,
            encoding: .heif,
            livePhotoMovieURL: nil,
            location: LocationFixture.location(latitude: -33.86, longitude: 151.21)
        )
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = PhotoCapturePipeline(aspectRatio: aspectRatio, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(photo)
        let delivered = try Data(contentsOf: capture.fileURL)
        let originalProperties = try DevicePhotoFixture.properties(of: original)
        let deliveredProperties = try DevicePhotoFixture.properties(of: delivered)
        let gps = try #require(deliveredProperties[kCGImagePropertyGPSDictionary] as? [CFString: Any])
        #expect(gps[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        for (key, value) in originalProperties {
            guard let dictionary = value as? [String: Any] else { continue }
            let deliveredDictionary = try #require(deliveredProperties[key] as? [String: Any], "\(key) is lost")
            #expect(Set(dictionary.keys).isSubset(of: Set(deliveredDictionary.keys)), "\(key) lost keys")
        }
        #expect(try DevicePhotoFixture.gainMap(of: delivered).hasVersionTag)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test(
        "A photo without a location and a RAW photo stay byte for byte",
        arguments: [
            (PhotoCaptureEncoding.heif, false),
            (.appleProRAW, true)
        ]
    )
    func untouched(encoding: PhotoCaptureEncoding, hasLocation: Bool) async throws {
        let original = try DevicePhotoFixture.makeCameraFile()
        let photo = CapturedPhoto(
            imageData: original,
            encoding: encoding,
            livePhotoMovieURL: nil,
            location: hasLocation ? LocationFixture.location() : nil
        )
        let store = CaptureTestSupport.makeFileStore()
        let pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: CameraFlowOutput(), store: store)
        let capture = try await pipeline.process(photo)
        #expect(try Data(contentsOf: capture.fileURL) == original)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A file ImageIO cannot read gets no location")
    func unreadable() {
        let outcome = PhotoLocationWriter.addingGPS(Self.gps, to: Data("not a photo".utf8))
        #expect(outcome == .unlocatable(LoggedReason("The photo cannot be read")))
    }

    static let allRatios: [CameraFlowAspectRatio] = [.fourByThree, .sixteenByNine, .square]

    private static func pixels(of data: Data) throws -> Data {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels = try #require(image.dataProvider?.data)
        return pixels as Data
    }
}
