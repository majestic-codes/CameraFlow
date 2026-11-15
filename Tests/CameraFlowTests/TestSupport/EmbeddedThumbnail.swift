//
//  EmbeddedThumbnail.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// The thumbnail a photo file embeds, read without one made of its image. ImageIO tells an embedded thumbnail of a
/// HEIC apart, and makes one of the image of a JPEG whether it embeds one or not, so the thumbnail of a JPEG is read
/// from the second directory of its EXIF.
enum EmbeddedThumbnail {

    /// The thumbnail the photo embeds, nil for a photo without one.
    static func image(in data: Data) throws -> CGImage? {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        guard CGImageSourceGetType(source) as String? == UTType.jpeg.identifier else {
            let options = [kCGImageSourceCreateThumbnailFromImageIfAbsent: false] as CFDictionary
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        }
        guard let thumbnail = try ExifReader(jpeg: data)?.thumbnail() else { return nil }
        let thumbnailSource = try #require(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(thumbnailSource, 0, nil))
    }
}

/// The TIFF structure of the EXIF of a JPEG: its directories of tags, in the byte order the header gives.
private struct ExifReader {
    private let bytes: [UInt8]
    /// Where the TIFF header starts, which the offsets of the directories count from.
    private let start: Int
    private let isLittleEndian: Bool

    /// The marker of the segment that holds the EXIF.
    private static let exifMarker: UInt8 = 0xE1
    /// The marker of the segment after which only the compressed image follows.
    private static let scanMarker: UInt8 = 0xDA
    private static let exifName: [UInt8] = Array("Exif".utf8) + [0, 0]
    private static let thumbnailOffsetTag = 0x0201
    private static let thumbnailLengthTag = 0x0202

    /// The EXIF of the JPEG, nil for a JPEG without one.
    init?(jpeg: Data) throws {
        let bytes = [UInt8](jpeg)
        var offset = 2
        while offset + 4 <= bytes.count, bytes[offset] == 0xFF, bytes[offset + 1] != Self.scanMarker {
            let length = Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            let name = offset + 4
            if bytes[offset + 1] == Self.exifMarker, name + Self.exifName.count <= bytes.count,
               Array(bytes[name..<(name + Self.exifName.count)]) == Self.exifName {
                self.bytes = bytes
                start = name + Self.exifName.count
                try #require(start + 8 <= bytes.count)
                isLittleEndian = bytes[start] == 0x49
                return
            }
            offset += 2 + length
        }
        return nil
    }

    /// The JPEG of the thumbnail the second directory points at, nil for an EXIF without one.
    func thumbnail() throws -> Data? {
        let firstOffset = try number(at: start + 4, size: 4)
        let firstDirectory = start + firstOffset
        let firstCount = try number(at: firstDirectory, size: 2)
        let secondOffset = try number(at: firstDirectory + 2 + firstCount * 12, size: 4)
        guard secondOffset != 0 else { return nil }
        let tags = try thumbnailTags(inDirectoryAt: start + secondOffset)
        guard let offset = tags[Self.thumbnailOffsetTag], let length = tags[Self.thumbnailLengthTag] else {
            return nil
        }
        try #require(start + offset + length <= bytes.count)
        return Data(bytes[(start + offset)..<(start + offset + length)])
    }

    /// The tags of a directory that place the thumbnail, by their number. Both hold one long number.
    private func thumbnailTags(inDirectoryAt directory: Int) throws -> [Int: Int] {
        var tags: [Int: Int] = [:]
        let entryCount = try number(at: directory, size: 2)
        for entry in 0..<entryCount {
            let entryStart = directory + 2 + entry * 12
            let tag = try number(at: entryStart, size: 2)
            guard tag == Self.thumbnailOffsetTag || tag == Self.thumbnailLengthTag else { continue }
            let value = try number(at: entryStart + 8, size: 4)
            tags[tag] = value
        }
        return tags
    }

    private func number(at offset: Int, size: Int) throws -> Int {
        try #require(offset >= 0 && offset + size <= bytes.count, "The EXIF ends before \(offset)")
        let digits = bytes[offset..<(offset + size)]
        let ordered = isLittleEndian ? Array(digits.reversed()) : Array(digits)
        return ordered.reduce(0) { $0 << 8 | Int($1) }
    }
}
