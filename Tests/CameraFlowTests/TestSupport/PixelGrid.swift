//
//  PixelGrid.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing

/// The pixels of an image as sRGB bytes, addressed from the top left corner.
struct PixelGrid {
    struct Pixel: Equatable, Sendable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8

        static let clear = Self(red: 0, green: 0, blue: 0, alpha: 0)

        init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        /// True when no channel is further away than a lossy encoding and a colour conversion move it.
        func isClose(to other: Self, tolerance: Int = 24) -> Bool {
            let pairs = [(red, other.red), (green, other.green), (blue, other.blue), (alpha, other.alpha)]
            return pairs.allSatisfy { abs(Int($0.0) - Int($0.1)) <= tolerance }
        }
    }

    let width: Int
    let height: Int
    private let bytes: [UInt8]
    private let bytesPerRow: Int

    init(_ image: CGImage) throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        width = image.width
        height = image.height
        bytesPerRow = context.bytesPerRow
        let buffer = UnsafeBufferPointer(
            start: data.assumingMemoryBound(to: UInt8.self),
            count: context.bytesPerRow * image.height
        )
        bytes = Array(buffer)
    }

    /// The pixels a file stores, without its orientation applied.
    init(fileAt url: URL) throws {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
        try self.init(image)
    }

    /// How far the pixels of a file are from those of another file of the same size: the mean difference of a
    /// channel, over every eighth pixel of every eighth row from `firstRow` on.
    static func distance(from first: URL, to second: URL, firstRow: Int = 0) throws -> Double {
        let firstPixels = try Self(fileAt: first)
        let secondPixels = try Self(fileAt: second)
        try #require(firstPixels.width == secondPixels.width && firstPixels.height == secondPixels.height)
        var total = 0
        var count = 0
        for row in stride(from: firstRow, to: firstPixels.height, by: 8) {
            for column in stride(from: 0, to: firstPixels.width, by: 8) {
                let one = try firstPixels[column, row]
                let other = try secondPixels[column, row]
                total += abs(Int(one.red) - Int(other.red))
                total += abs(Int(one.green) - Int(other.green))
                total += abs(Int(one.blue) - Int(other.blue))
                count += 3
            }
        }
        return Double(total) / Double(count)
    }

    /// The pixel at a column and a row, which the test fails at when the image has no such pixel.
    subscript(column: Int, row: Int) -> Pixel {
        get throws {
            let isInside = (0..<width).contains(column) && (0..<height).contains(row)
            try #require(isInside, "The image of \(width) x \(height) has no pixel \(column), \(row)")
            let offset = row * bytesPerRow + column * 4
            return Pixel(
                red: bytes[offset],
                green: bytes[offset + 1],
                blue: bytes[offset + 2],
                alpha: bytes[offset + 3]
            )
        }
    }
}
