//
//  MarkupFailure.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Why a drawing cannot be opened, kept, shown or written into a copy of its photo. It describes itself in words
/// that name a photo by its file, without the folders it is in.
enum MarkupFailure: Error, Equatable, CustomStringConvertible {
    /// The engine that made the drawing does not exist on this system.
    case engineUnavailable(MarkupEngine)
    /// The engine cannot read the drawing's data. The text is the engine's own reason.
    case undecodableDrawing(MarkupEngine, String)
    /// The engine cannot serialise the drawing on its canvas. The text is the engine's own reason.
    case unencodableDrawing(MarkupEngine, String)
    /// A drawing needs a canvas with an area.
    case emptyCanvas(CGSize)
    /// There is no bitmap of this many pixels to draw into.
    case cannotCreateBitmap(width: Int, height: Int)
    /// ImageIO cannot decode the photo the copy is made of.
    case unreadablePhoto(URL)
    /// ImageIO cannot encode the copy or carry the photo's metadata into it. The text says which.
    case cannotEncodeCopy(String)
    /// The file of the copy cannot be written. The text says why.
    case cannotStoreCopy(String)
    /// The device has too little room left for the file of the copy.
    case notEnoughStorage

    /// The failure in words, which name a photo by its file without the folders it is in.
    var description: String {
        switch self {
        case let .engineUnavailable(engine): "The drawing engine \(engine) does not exist on this system"
        case let .undecodableDrawing(engine, reason): "The drawing engine \(engine) cannot read the drawing: \(reason)"
        case let .unencodableDrawing(engine, reason): "The drawing engine \(engine) cannot keep the drawing: \(reason)"
        case let .emptyCanvas(size): "A drawing needs a canvas with an area, not \(size.width) x \(size.height)"
        case let .cannotCreateBitmap(width, height): "There is no bitmap of \(width) x \(height) pixels to draw into"
        case let .unreadablePhoto(url): "The photo \(url.lastPathComponent) cannot be read"
        case let .cannotEncodeCopy(reason): reason
        case let .cannotStoreCopy(reason): reason
        case .notEnoughStorage: "The device has too little room left for the copy"
        }
    }
}
