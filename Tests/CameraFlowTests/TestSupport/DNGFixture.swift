//
//  DNGFixture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// A little-endian DNG laid out as a camera writes one: its first image file directory holds a small 8-bit RGB
/// preview (NewSubfileType 1) with the DNG tags, and the directory it points to (SubIFDs) holds the RAW image, a
/// LinearRaw picture of three 16-bit samples. From bytes alone ImageIO reads such a file as the TIFF of its preview.
enum DNGFixture {
    static let rawWidth = 256
    static let rawHeight = 192
    static let previewWidth = 64
    static let previewHeight = 48

    /// A field of an image file directory: a tag, its TIFF field type, its value count and its value bytes.
    private struct Field {
        let tag: UInt16
        let fieldType: UInt16
        let count: Int
        let value: Data

        static func short(_ tag: UInt16, _ values: [UInt16]) -> Self {
            Self(tag: tag, fieldType: 3, count: values.count, value: littleEndian(values))
        }

        static func long(_ tag: UInt16, _ values: [UInt32]) -> Self {
            Self(tag: tag, fieldType: 4, count: values.count, value: littleEndian(values))
        }

        private static func littleEndian<Value: FixedWidthInteger>(_ values: [Value]) -> Data {
            values.reduce(into: Data()) { $0.appendLittleEndian($1) }
        }

        static func ascii(_ tag: UInt16, _ text: String) -> Self {
            let value = Data(text.utf8) + Data([0])
            return Self(tag: tag, fieldType: 2, count: value.count, value: value)
        }

        static func byte(_ tag: UInt16, _ values: [UInt8]) -> Self {
            Self(tag: tag, fieldType: 1, count: values.count, value: Data(values))
        }

        static func rational(_ tag: UInt16, _ fractions: [(Int32, Int32)], isSigned: Bool) -> Self {
            var value = Data()
            for (numerator, denominator) in fractions {
                value.appendLittleEndian(numerator)
                value.appendLittleEndian(denominator)
            }
            return Self(tag: tag, fieldType: isSigned ? 10 : 5, count: fractions.count, value: value)
        }
    }

    /// The file being written: the header, then values and directories as they are appended.
    private struct FileBuilder {
        var bytes = Data("II".utf8)

        init() {
            bytes.appendLittleEndian(UInt16(42))
            bytes.appendLittleEndian(UInt32(0))
        }

        /// Appends bytes at an even offset and returns the offset.
        mutating func append(_ value: Data) -> UInt32 {
            alignToWord()
            let offset = UInt32(bytes.count)
            bytes.append(value)
            return offset
        }

        /// Appends a directory of the fields, sorted by tag, and returns its offset. A value longer than four bytes
        /// goes before the directory, which points to it.
        mutating func appendDirectory(_ fields: [Field]) -> UInt32 {
            let sorted = fields.sorted { $0.tag < $1.tag }
            let valueOffsets = sorted.map { field in field.value.count > 4 ? append(field.value) : nil }
            alignToWord()
            let offset = UInt32(bytes.count)
            bytes.appendLittleEndian(UInt16(sorted.count))
            for (field, valueOffset) in zip(sorted, valueOffsets) {
                bytes.appendLittleEndian(field.tag)
                bytes.appendLittleEndian(field.fieldType)
                bytes.appendLittleEndian(UInt32(field.count))
                if let valueOffset {
                    bytes.appendLittleEndian(valueOffset)
                } else {
                    bytes.append(field.value + Data(count: 4 - field.value.count))
                }
            }
            bytes.appendLittleEndian(UInt32(0))
            return offset
        }

        mutating func setFirstDirectory(at offset: UInt32) {
            var littleEndian = offset.littleEndian
            bytes.replaceSubrange(4..<8, with: Data(bytes: &littleEndian, count: 4))
        }

        private mutating func alignToWord() {
            if !bytes.count.isMultiple(of: 2) {
                bytes.append(0)
            }
        }
    }

    static func make() -> Data {
        var file = FileBuilder()
        let rawPixels = rawPixels()
        let rawOffset = file.append(rawPixels)
        let preview = previewPixels()
        let previewOffset = file.append(preview)
        let rawDirectory = file.appendDirectory([
            .long(254, [0]),
            .long(256, [UInt32(rawWidth)]),
            .long(257, [UInt32(rawHeight)]),
            .short(258, [16, 16, 16]),
            .short(259, [1]),
            // LinearRaw.
            .short(262, [34_892]),
            .long(273, [rawOffset]),
            .short(277, [3]),
            .long(278, [UInt32(rawHeight)]),
            .long(279, [UInt32(rawPixels.count)]),
            .short(284, [1]),
            .long(50_714, [0, 0, 0]),
            .long(50_717, [65_535, 65_535, 65_535])
        ])
        let colorMatrix: [Int32] = [32_406, -15_372, -4_986, -9_689, 18_758, 415, 557, -2_040, 10_570]
        let firstDirectory = file.appendDirectory([
            .long(254, [1]),
            .long(256, [UInt32(previewWidth)]),
            .long(257, [UInt32(previewHeight)]),
            .short(258, [8, 8, 8]),
            .short(259, [1]),
            .short(262, [2]),
            .ascii(271, "Fixture"),
            .ascii(272, "Linear Preview"),
            .long(273, [previewOffset]),
            .short(274, [1]),
            .short(277, [3]),
            .long(278, [UInt32(previewHeight)]),
            .long(279, [UInt32(preview.count)]),
            .short(284, [1]),
            .long(330, [rawDirectory]),
            .byte(50_706, [1, 4, 0, 0]),
            .byte(50_707, [1, 1, 0, 0]),
            .ascii(50_708, "Fixture Linear Preview"),
            .rational(50_721, colorMatrix.map { ($0, 10_000) }, isSigned: true),
            .rational(50_728, [(1, 1), (1, 1), (1, 1)], isSigned: false),
            .short(50_778, [21])
        ])
        file.setFirstDirectory(at: firstDirectory)
        return file.bytes
    }

    /// Writes the DNG into a new file with the extension that types it.
    static func makeFile(in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("dng")
        try make().write(to: url)
        return url
    }

    /// Smooth gradients of three 16-bit samples.
    private static func rawPixels() -> Data {
        var pixels = Data(capacity: rawWidth * rawHeight * 6)
        for row in 0..<rawHeight {
            for column in 0..<rawWidth {
                pixels.appendLittleEndian(UInt16(column * 40_000 / rawWidth + 2_000))
                pixels.appendLittleEndian(UInt16(row * 30_000 / rawHeight + 3_000))
                pixels.appendLittleEndian(UInt16(30_000 - column * 20_000 / rawWidth))
            }
        }
        return pixels
    }

    private static func previewPixels() -> Data {
        var pixels = Data(capacity: previewWidth * previewHeight * 3)
        for _ in 0..<previewHeight {
            for column in 0..<previewWidth {
                pixels.append(contentsOf: [UInt8(column * 255 / previewWidth), 60, 200])
            }
        }
        return pixels
    }
}

private extension Data {

    mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        var littleEndian = value.littleEndian
        append(Data(bytes: &littleEndian, count: MemoryLayout<Value>.size))
    }
}
