//
//  PaperMarkupFeaturesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import PaperKit
import Testing
@testable import CameraFlow

/// What the PaperKit canvas offers: the features a stored drawing renders, so the review and the copy show what
/// was drawn, and no feature a later system adds.
@Suite("Features of the PaperKit canvas")
struct PaperMarkupFeaturesTests {
    /// An element of PaperKit that its live canvas shows and a stored drawing does not render.
    enum LiveOnlyElement: CaseIterable, Sendable {
        case loupe
        case link
    }

    /// An element the canvas offers that a test can make. A sticker comes from the system's sticker picker only.
    enum OfferedElement: CaseIterable, Sendable {
        case stroke
        case shape
        case text
        case image
    }

    private static let canvasSize = CGSize(width: 100, height: 100)
    private static let elementFrame = CGRect(x: 25, y: 25, width: 50, height: 50)

    @Test("The canvas offers the first version of PaperKit's features without the loupe and the link")
    @available(iOS 26, macOS 26, *)
    func supported() {
        let supported = PaperMarkupFeatures.supported
        let version1 = FeatureSet.version1
        #expect(supported.features == version1.features.subtracting([.loupes, .links]))
        #expect(supported.contentVersion == version1.contentVersion)
        #expect(supported.shapes == version1.shapes)
        #expect(supported.inks == version1.inks)
        #expect(supported.isSubset(of: version1))
    }

    @Test(
        "A loupe or a link alone renders nothing in a stored drawing, so the canvas counts as empty",
        arguments: LiveOnlyElement.allCases
    )
    @available(iOS 27, macOS 27, *)
    func liveOnlyElement(element: LiveOnlyElement) async throws {
        var markup = PaperMarkup(emptyCanvasOf: Self.canvasSize)
        switch element {
        case .loupe:
            let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
            markup.subelements.append(LoupeMarkup(frame: Self.elementFrame, strokeColor: red, lineWidth: 4))
        case .link:
            let url = try #require(URL(string: "https://example.com"))
            markup.subelements.append(LinkMarkup(url: url, frame: Self.elementFrame))
        }
        #expect(markup.isEmpty)
        #expect(try await Self.inkedPixelCount(of: markup) == 0)
    }

    @Test(
        "Strokes, shapes, text and images the canvas offers render in a stored drawing",
        arguments: OfferedElement.allCases
    )
    @available(iOS 26, macOS 26, *)
    func offeredElement(element: OfferedElement) async throws {
        var markup = PaperMarkup(emptyCanvasOf: Self.canvasSize)
        let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        switch element {
        case .stroke:
            let strokes = try PencilStrokeFixture.redInk().pencilDrawing()
            markup.append(contentsOf: strokes)
        case .shape:
            let shape = ShapeConfiguration(type: .rectangle, fillColor: red)
            markup.insertNewShape(configuration: shape, frame: Self.elementFrame)
        case .text:
            markup.insertNewTextbox(attributedText: AttributedString("Markup"), frame: Self.elementFrame)
        case .image:
            let image = try Self.redImage()
            markup.insertNewImage(image, frame: Self.elementFrame)
        }
        #expect(markup.isEmpty == false)
        #expect(try await Self.inkedPixelCount(of: markup) > 0)
    }

    /// How many pixels a stored drawing of `markup` covers when the renderer draws it at its canvas's size.
    @available(iOS 26, macOS 26, *)
    private static func inkedPixelCount(of markup: PaperMarkup) async throws -> Int {
        let data = try await markup.serialized()
        let drawing = try MarkupDrawing(engine: .paperKit, data: data, canvasSize: canvasSize)
        let image = try await SystemMarkupRenderer().image(of: drawing, pixelSize: canvasSize)
        let pixels = try PixelGrid(image)
        var inkedCount = 0
        for row in 0..<pixels.height {
            for column in 0..<pixels.width where try pixels[column, row] != .clear {
                inkedCount += 1
            }
        }
        return inkedCount
    }

    /// A red square picture to insert.
    private static func redImage() throws -> CGImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try #require(
            CGContext(
                data: nil,
                width: 20,
                height: 20,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        )
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        return try #require(context.makeImage())
    }
}
