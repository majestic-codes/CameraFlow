//
//  MarkupRenderer.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Turns a stored drawing into pixels, with the engine that made it. Every failure is a `MarkupFailure`.
protocol MarkupRenderer: Sendable {

    /// The drawing alone on a transparent background, its canvas stretched over `pixelSize`.
    func image(of drawing: MarkupDrawing, pixelSize: CGSize) async throws -> CGImage

    /// Writes a copy of the photo with the drawing over it into `directory`, in the output, and returns where it
    /// is. The photo is decoded once and the copy encoded once.
    ///
    /// The copy has the photo's pixel size within the size limit of the output and within 48 MP, the format of the
    /// output at its quality, and the photo's metadata unless the output strips it. With the default output that is
    /// the photo's full size and its file type for a JPEG, a HEIC, a PNG and a TIFF, and a HEIC for every other type.
    /// Its pixels are upright, so its orientation is 1. It keeps the photo's bit depth and, with the metadata, the
    /// photo's auxiliary images turned upright with it: the HDR gain maps, at no boost under the drawing, the mattes
    /// and depth. The file gets a free numbered name after the photo's and never replaces a file. The receiver owns
    /// it.
    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) async throws -> URL
}
