//
//  OverlayCopyFailure.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Why a copy of a photo with an overlay cannot be written. The overlay's own failures come as they are thrown.
enum OverlayCopyFailure: Error, Equatable, CustomStringConvertible {
    /// ImageIO cannot read the photo the copy is made of.
    case unreadablePhoto(URL)
    /// There is no bitmap of this many pixels to draw into.
    case cannotCreateBitmap(width: Int, height: Int)
    /// ImageIO cannot encode the copy or carry the photo's metadata into it. The text says which.
    case cannotEncode(String)
    /// The file of the copy cannot be written. The text says why.
    case cannotStore(String)
    /// The device has too little room left for the file of the copy.
    case notEnoughStorage

    /// The failure in words, which name a photo by its file without the folders it is in.
    var description: String {
        switch self {
        case let .unreadablePhoto(url): "The photo \(url.lastPathComponent) cannot be read"
        case let .cannotCreateBitmap(width, height): "There is no bitmap of \(width) x \(height) pixels to draw into"
        case let .cannotEncode(reason): reason
        case let .cannotStore(reason): reason
        case .notEnoughStorage: "The device has too little room left for the copy"
        }
    }
}
