//
//  RecordingMarkupRenderer.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
@testable import CameraFlow

/// A renderer that paints nothing and records what it was asked for. Its pictures are blank bitmaps of the size
/// asked for, and a copy is a small JPEG file. It fails where the test tells it to, with a gate it writes a copy
/// only once the gate has opened, and it holds the picture the test names until that picture's gate opens.
actor RecordingMarkupRenderer: MarkupRenderer {
    struct Picture: Equatable {
        let drawing: MarkupDrawing
        let pixelSize: CGSize
    }

    private(set) var pictures: [Picture] = []
    /// The photos a copy was asked for, in the order of the calls.
    private(set) var copiedPhotoURLs: [URL] = []
    /// The outputs the copies were asked in, in the order of the calls.
    private(set) var copyOutputs: [CameraFlowOutput] = []
    private var failingCopyNumber: Int?
    private var failsPictures = false
    private let gate: CallGate?
    /// The picture to hold, counted from one over the calls so far and to come, with the gate it waits at.
    private var heldPicture: (number: Int, gate: CallGate)?

    static let failure = MarkupFailure.cannotEncodeCopy("The test asked for a failure")

    init(gate: CallGate? = nil) {
        self.gate = gate
    }

    /// Makes the copy with this number fail, counted from one over the calls so far and to come.
    func failCopy(number: Int) {
        failingCopyNumber = number
    }

    func failPictures() {
        failsPictures = true
    }

    /// Holds the picture with this number, counted from one over the calls so far and to come, until the gate opens.
    /// The other pictures are made meanwhile.
    func holdPicture(number: Int, at gate: CallGate) {
        heldPicture = (number, gate)
    }

    func image(of drawing: MarkupDrawing, pixelSize: CGSize) async throws -> CGImage {
        pictures.append(Picture(drawing: drawing, pixelSize: pixelSize))
        if let heldPicture, heldPicture.number == pictures.count {
            await heldPicture.gate.pass()
        }
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        guard !failsPictures,
              let bitmap = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = bitmap.makeImage() else {
            throw MarkupFailure.cannotCreateBitmap(width: width, height: height)
        }
        return image
    }

    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) async throws -> URL {
        copiedPhotoURLs.append(photoURL)
        copyOutputs.append(output)
        let number = copiedPhotoURLs.count
        await gate?.pass()
        guard number != failingCopyNumber else {
            throw Self.failure
        }
        let name = photoURL.deletingPathExtension().lastPathComponent + "-markup-\(number)"
        let copyURL = directory.appendingPathComponent(name).appendingPathExtension("copy")
        try FlowTestSupport.makeJPEG().write(to: copyURL, options: .withoutOverwriting)
        return copyURL
    }
}
