//
//  HandedOverContentTypeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// The types a photo with a drawing reaches the app with, over the system renderer: each the type its file has.
@MainActor
@Suite("The types of the original and of the copy with a drawing", .temporaryDirectory, .timeLimit(.minutes(1)))
struct HandedOverContentTypeTests {
    /// A picked file of a type ImageIO reads and cannot write.
    enum Pick: String, Sendable {
        case gif
        case dng

        func data() throws -> Data {
            switch self {
            case .gif:
                let directory = TestDirectory.current.appendingPathComponent("originals")
                let url = try OrientedPhotoFixture.makeFile(orientation: 1, type: .gif, in: directory)
                return try Data(contentsOf: url)
            case .dng:
                return DNGFixture.make()
            }
        }
    }

    /// A pick under an output format, and the types its original and its copy come in.
    struct TypeCase: Sendable, CustomTestStringConvertible {
        let pick: Pick
        let format: CameraFlowOutputFormat
        let originalType: String
        let copyType: String

        var testDescription: String {
            "\(pick.rawValue) under \(format)"
        }
    }

    nonisolated static let typeCases = [
        TypeCase(pick: .gif, format: .original, originalType: "com.compuserve.gif", copyType: "public.heic"),
        TypeCase(pick: .dng, format: .original, originalType: "com.adobe.raw-image", copyType: "public.heic"),
        TypeCase(pick: .gif, format: .jpeg(quality: 0.8), originalType: "public.jpeg", copyType: "public.jpeg"),
        TypeCase(pick: .dng, format: .jpeg(quality: 0.8), originalType: "public.jpeg", copyType: "public.jpeg")
    ]

    @Test(
        "The copy comes with the type it is written in, a HEIC where ImageIO cannot write the original's",
        arguments: typeCases
    )
    func drawnCopy(typeCase: TypeCase) async throws {
        let outcome = FlowOutcome()
        var output = CameraFlowOutput()
        output.format = typeCase.format
        let photoSet = PhotoSetModel(
            limit: .unlimited,
            fileStore: CaptureTestSupport.makeFileStore(),
            output: output,
            renderer: SystemMarkupRenderer()
        ) { [outcome] in
            outcome.handedOver.append($0)
        }
        let pick = FakeLibraryPick(data: try typeCase.pick.data(), fileExtension: typeCase.pick.rawValue)
        await photoSet.importPicks([pick])
        let picked = try #require(photoSet.photos.first)
        photoSet.setDrawing(try PencilStrokeFixture.redInk(), ofPhoto: picked.id)
        await photoSet.handOver()
        let photo = try #require(outcome.handedOver.first?.first)
        #expect(photo.original.contentType.identifier == typeCase.originalType)
        let copy = try #require(photo.markedUp)
        #expect(copy.contentType.identifier == typeCase.copyType)
        #expect(try ImageFile.contentType(of: copy.url).identifier == typeCase.copyType)
        #expect(photo.result == copy)
        try FlowTestSupport.discardFiles(of: [photo])
    }
}
