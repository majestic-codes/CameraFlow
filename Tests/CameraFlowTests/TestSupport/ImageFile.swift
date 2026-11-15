//
//  ImageFile.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// What ImageIO reads of an image file or of its bytes: the type, and the properties of the primary image.
enum ImageFile {

    static func contentType(of url: URL) throws -> UTType {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try contentType(of: source)
    }

    static func contentType(of data: Data) throws -> UTType {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try contentType(of: source)
    }

    /// The type identifier ImageIO reads, for a type the system may not declare as a `UTType`: the simulator does
    /// not declare `public.radiance`, which its ImageIO reads.
    static func typeIdentifier(of url: URL) throws -> String {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceGetType(source)) as String
    }

    static func properties(of url: URL) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
    }

    private static func contentType(of source: CGImageSource) throws -> UTType {
        let identifier = try #require(CGImageSourceGetType(source))
        return try #require(UTType(identifier as String))
    }
}
