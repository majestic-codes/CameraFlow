//
//  MarkedUpCopyOutputTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The copy with a drawing in the output of its photo, checked on real encoded files: it is encoded once, from
/// the fullest picture, at the size, in the format and at the quality of the output.
@Suite("Marked-up copy: the output it is written in", .temporaryDirectory, .timeLimit(.minutes(1)))
struct MarkedUpCopyOutputTests {
    private let directory = CaptureTestSupport.makeFileStore().directory

    private func largeJPEGFile() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("large.jpg")
        try LargePhotoFixture.jpeg.get().write(to: url)
        return url
    }

    /// The copy of a photo in an output, with nothing drawn over it.
    private func writeCopy(of original: URL, output: CameraFlowOutput) async throws -> URL {
        try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: directory,
            label: "markup",
            output: output
        ) { _, _ in }
    }

    /// An output and the copy it makes of the 2560 x 1920 JPEG.
    struct OutputCase: Sendable {
        let size: CameraFlowOutputSize
        let format: CameraFlowOutputFormat
        let type: UTType
        let width: Int
        let height: Int
    }

    static let outputCases = [
        OutputCase(size: .longSide(maximum: 1920), format: .jpeg(quality: 1), type: .jpeg, width: 1920, height: 1440),
        OutputCase(size: .longSide(maximum: 1000), format: .heic(quality: 0.6), type: .heic, width: 1000, height: 750),
        OutputCase(size: .original, format: .heic(quality: 0.8), type: .heic, width: 2560, height: 1920),
        OutputCase(size: .longSide(maximum: 4000), format: .original, type: .jpeg, width: 2560, height: 1920)
    ]

    @Test("The copy has the size and the format of the output, with the overlay drawn at it", arguments: outputCases)
    func sizeAndFormat(outputCase: OutputCase) async throws {
        let original = try largeJPEGFile()
        let output = CameraFlowOutput(size: outputCase.size, format: outputCase.format)
        let size = CGSize(width: outputCase.width, height: outputCase.height)
        let copy = try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: directory,
            label: "markup",
            output: output
        ) { _, drawn in
            #expect(drawn == size)
        }
        let facts = try LargePhotoFixture.facts(of: copy)
        #expect(facts.type == outputCase.type)
        #expect(facts.width == outputCase.width)
        #expect(facts.height == outputCase.height)
        #expect(copy.pathExtension == outputCase.type.preferredFilenameExtension)
    }

    @Test("The copy is encoded once at the quality of the output: at 1 it is closer to the photo than at 0.9")
    func quality() async throws {
        let original = try largeJPEGFile()
        var copies: [Double: URL] = [:]
        for quality in [1, 0.9, 0.5] {
            let output = CameraFlowOutput(format: .jpeg(quality: quality))
            copies[quality] = try await writeCopy(of: original, output: output)
        }
        let best = try #require(copies[1])
        let good = try #require(copies[0.9])
        let small = try #require(copies[0.5])
        let bestDistance = try PixelGrid.distance(from: best, to: original)
        let goodDistance = try PixelGrid.distance(from: good, to: original)
        // How much closer depends on the JPEG encoder of the system, so only the order is the package's to keep.
        #expect(bestDistance < goodDistance, "\(bestDistance) at 1, \(goodDistance) at 0.9")
        let bestBytes = try LargePhotoFixture.facts(of: best).byteCount
        let goodBytes = try LargePhotoFixture.facts(of: good).byteCount
        let smallBytes = try LargePhotoFixture.facts(of: small).byteCount
        #expect(bestBytes > goodBytes)
        #expect(goodBytes > smallBytes)
    }

    @Test("A copy for an output that strips the metadata has none, and one for an output that keeps them has them")
    func metadata() async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 6, type: .jpeg, in: directory)
        let stripped = CameraFlowOutput(format: .jpeg(quality: 0.8), metadata: .stripped)
        let kept = CameraFlowOutput(format: .jpeg(quality: 0.8))
        let bare = try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: directory,
            label: "markup",
            output: stripped
        ) { _, _ in }
        let full = try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: directory,
            label: "markup",
            output: kept
        ) { _, _ in }
        let bareProperties = try ImageFile.properties(of: bare)
        let fullProperties = try ImageFile.properties(of: full)
        #expect(bareProperties[kCGImagePropertyGPSDictionary] == nil)
        #expect(fullProperties[kCGImagePropertyGPSDictionary] != nil)
        #expect(bareProperties[kCGImagePropertyPixelWidth] as? Int == OrientedPhotoFixture.uprightWidth)
        #expect(fullProperties[kCGImagePropertyPixelWidth] as? Int == OrientedPhotoFixture.uprightWidth)
    }

    @Test(
        "A photo of more pixels than a copy may have is scaled down to them, whatever the output",
        .needsDeviceImageIO(.heicThumbnailRounding),
        arguments: [(3072, 64), (6000, 89), (12288, 128)]
    )
    func pixelBudget(maximumPixelCount: Int, longSide: Int) async throws {
        let original = try OrientedPhotoFixture.makeFile(orientation: 6, type: .heic, in: directory)
        var drawnSizes: [CGSize] = []
        let copy = try await OverlayPhotoWriter.writeCopy(
            of: original,
            into: directory,
            label: "markup",
            maximumPixelCount: maximumPixelCount
        ) { _, size in
            drawnSizes.append(size)
        }
        let properties = try ImageFile.properties(of: copy)
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(width == longSide)
        #expect(width * height <= maximumPixelCount)
        #expect(drawnSizes == [CGSize(width: width, height: height)])
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == width)
        #expect(exif[kCGImagePropertyExifPixelYDimension] as? Int == height)
    }

    @Test("The pixels a copy may have are those of a 48 MP photo of the iPhone's camera")
    func defaultPixelBudget() {
        #expect(OverlayPhotoWriter.maximumPixelCount == 8064 * 6048)
    }

    @MainActor
    @Test("The set draws the copy over the camera's own photo and encodes it once, in the output of its photo")
    func copyOfTheSet() async throws {
        let writer = FakePhotoLibraryWriter()
        let harness = QualityHarness(
            output: CameraFlowOutput(format: .jpeg(quality: 1)),
            librarySaving: CaptureTestSupport.makeLibrarySaving(writer: writer)
        )
        await harness.camera.start()
        let photo = try await harness.takeLargePhoto()
        let cameraURL = try #require(photo.libraryFileURL)
        let cameraPhoto = directory.appendingPathComponent("camera.heic")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: cameraURL, to: cameraPhoto)
        harness.photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: photo.id)
        await harness.photoSet.handOver()
        let handedOver = try #require(harness.outcome.handedOver.first?.first)
        let copy = try #require(handedOver.markedUp?.url)
        let facts = try LargePhotoFixture.facts(of: copy)
        #expect(facts.type == .jpeg)
        #expect(facts.width == LargePhotoFixture.width)
        #expect(facts.height == LargePhotoFixture.height)
        let copyDistance = try PixelGrid.distance(from: copy, to: cameraPhoto)
        let outputDistance = try PixelGrid.distance(from: handedOver.original.url, to: cameraPhoto)
        let comment = Comment("\(copyDistance) for the copy, \(outputDistance) for the photo")
        #expect(copyDistance <= outputDistance * 1.5 + 0.5, comment)
        try FlowTestSupport.discardFiles(of: [handedOver])
    }
}
