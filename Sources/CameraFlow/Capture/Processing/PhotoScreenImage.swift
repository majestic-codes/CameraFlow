//
//  PhotoScreenImage.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// A photo file as a picture for the screen: upright, scaled down from the full image and never taken from the
/// small thumbnail a file may embed.
enum PhotoScreenImage {

    /// Decodes the picture off the main actor, at most `maximumPixelSize` on its long side. The pixels are decoded
    /// here, so drawing the picture later costs no decoding.
    @concurrent
    static func decode(url: URL, maximumPixelSize: Int) async throws -> CGImage {
        let photo: ImageSourcePhoto
        do {
            photo = try ImageSourcePhoto(url: url)
        } catch {
            throw CameraServiceError.noImageData
        }
        guard let image = photo.uprightImage(maximumLongSide: maximumPixelSize, cachesImmediately: true) else {
            throw CameraServiceError.noImageData
        }
        return image
    }
}
