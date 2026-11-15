//
//  SystemMarkupRenderer.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Renders stored drawings with PencilKit and PaperKit, off the main actor: a full-size copy takes a while to
/// decode, paint and encode.
struct SystemMarkupRenderer: MarkupRenderer {
    /// The label in the name of a copy with a drawing, such as `photo-markup-1.heic`.
    static let copyLabel = "markup"

    @concurrent
    func image(of drawing: MarkupDrawing, pixelSize: CGSize) async throws -> CGImage {
        let painter = try Self.painter(for: drawing)
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        // Display P3 holds every colour the system tool picker offers.
        guard width > 0, height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let bitmap = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw MarkupFailure.cannotCreateBitmap(width: width, height: height)
        }
        try await painter.paint(in: bitmap, size: CGSize(width: width, height: height))
        guard let image = bitmap.makeImage() else {
            throw MarkupFailure.cannotCreateBitmap(width: width, height: height)
        }
        return image
    }

    @concurrent
    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) async throws -> URL {
        let painter = try Self.painter(for: drawing)
        do {
            return try await OverlayPhotoWriter.writeCopy(
                of: photoURL,
                into: directory,
                label: Self.copyLabel,
                output: output
            ) { bitmap, size in
                try await painter.paint(in: bitmap, size: size)
            }
        } catch let failure as OverlayCopyFailure {
            throw MarkupFailure(failure)
        }
    }

    /// The painter of the engine that made the drawing.
    private static func painter(for drawing: MarkupDrawing) throws -> any MarkupPainter {
        switch drawing.engine {
        case .pencilKit:
            return try PencilMarkupPainter(drawing)
        case .paperKit:
            guard #available(iOS 26, macOS 26, *) else {
                throw MarkupFailure.engineUnavailable(.paperKit)
            }
            return try PaperMarkupPainter(drawing)
        }
    }
}

private extension MarkupFailure {
    /// The failure of a copy with a drawing, as the markup tells it.
    init(_ failure: OverlayCopyFailure) {
        self = switch failure {
        case let .unreadablePhoto(url): .unreadablePhoto(url)
        case let .cannotCreateBitmap(width, height): .cannotCreateBitmap(width: width, height: height)
        case let .cannotEncode(reason): .cannotEncodeCopy(reason)
        case let .cannotStore(reason): .cannotStoreCopy(reason)
        case .notEnoughStorage: .notEnoughStorage
        }
    }
}
