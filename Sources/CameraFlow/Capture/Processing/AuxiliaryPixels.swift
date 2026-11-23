//
//  AuxiliaryPixels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// The pixel buffer of an auxiliary image as its description gives it: one plane of rows of whole pixels, each row
/// `bytesPerRow` long, padding included.
struct AuxiliaryPixels {
    /// Why the pixel buffer of an auxiliary image cannot be read.
    enum Failure: Error, Equatable, CustomStringConvertible {
        case unknownPixelFormat(type: String, pixelFormat: UInt32)
        case malformed(String)

        var description: String {
            switch self {
            case let .unknownPixelFormat(type, pixelFormat): "\(type) has the unknown pixel format \(pixelFormat)"
            case let .malformed(type): "\(type) has no readable pixel buffer"
            }
        }
    }

    private(set) var data: Data
    private(set) var width: Int
    private(set) var height: Int
    private(set) var bytesPerRow: Int
    let pixelFormat: OSType
    let bytesPerPixel: Int
    /// The description the pixels came with, which may hold more than their layout.
    private var pixelDescription: [CFString: Any]

    /// The pixels of an auxiliary image's info. Fails for a description that cannot be read, a pixel format of more
    /// than one plane or unknown, and fewer bytes than the description says.
    init(info: [CFString: Any], type: CFString) throws(Failure) {
        let typeName = type as String
        guard let data = info[kCGImageAuxiliaryDataInfoData] as? Data,
              let description = info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any],
              let width = description["Width" as CFString] as? Int,
              let height = description["Height" as CFString] as? Int,
              let bytesPerRow = description["BytesPerRow" as CFString] as? Int,
              let pixelFormat = description["PixelFormat" as CFString] as? UInt32 else {
            throw .malformed(typeName)
        }
        guard let bytesPerPixel = Self.bytesPerPixel(of: pixelFormat) else {
            throw .unknownPixelFormat(type: typeName, pixelFormat: pixelFormat)
        }
        guard width > 0, height > 0, bytesPerRow >= width * bytesPerPixel, data.count >= bytesPerRow * height else {
            throw .malformed(typeName)
        }
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixelFormat = pixelFormat
        self.bytesPerPixel = bytesPerPixel
        pixelDescription = description
    }

    /// The same kind of pixels in another layout: rows without padding.
    private func withPixels(_ pixels: Data, width: Int, height: Int) -> Self {
        var relaid = self
        relaid.data = pixels
        relaid.width = width
        relaid.height = height
        relaid.bytesPerRow = width * bytesPerPixel
        return relaid
    }

    /// Gain maps and mattes have one byte a pixel, which Core Graphics draws as grey.
    var isOneByte: Bool {
        pixelFormat == kCVPixelFormatType_OneComponent8
    }

    /// The auxiliary image's info with these pixels and their description, the rest of the info as it is.
    func replacingPixels(in info: [CFString: Any]) -> [CFString: Any] {
        var updatedDescription = pixelDescription
        updatedDescription["Width" as CFString] = width
        updatedDescription["Height" as CFString] = height
        updatedDescription["BytesPerRow" as CFString] = bytesPerRow
        updatedDescription["PixelFormat" as CFString] = pixelFormat
        var updatedInfo = info
        updatedInfo[kCGImageAuxiliaryDataInfoData] = data
        updatedInfo[kCGImageAuxiliaryDataInfoDataDescription] = updatedDescription
        return updatedInfo
    }

    /// One-byte pixels of the same size with other levels: `levels` has one byte a pixel, in rows without padding.
    func withLevels(_ levels: Data) -> Self {
        withPixels(levels, width: width, height: height)
    }

    /// The pixels of a rectangle of whole pixels inside them, in rows without padding.
    func cropped(left: Int, top: Int, width croppedWidth: Int, height croppedHeight: Int) -> Self {
        let rowLength = croppedWidth * bytesPerPixel
        var cropped = Data(capacity: rowLength * croppedHeight)
        for row in top..<(top + croppedHeight) {
            let start = data.startIndex + row * bytesPerRow + left * bytesPerPixel
            cropped.append(data[start..<(start + rowLength)])
        }
        return withPixels(cropped, width: croppedWidth, height: croppedHeight)
    }

    /// The pixels turned the way `orientation` turns the photo upright, each pixel moved whole, in rows without
    /// padding, and an orientation their description gives, as depth has, is 1. The pixels of the photo's orientation
    /// 1 are kept as they are.
    func upright(_ orientation: CGImagePropertyOrientation) -> Self {
        guard orientation != .up else { return self }
        let isTurned = orientation.swapsSides
        let uprightWidth = isTurned ? height : width
        let uprightHeight = isTurned ? width : height
        let rowLength = uprightWidth * bytesPerPixel
        var turned = Data(count: rowLength * uprightHeight)
        turned.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) in
            data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                for row in 0..<uprightHeight {
                    for column in 0..<uprightWidth {
                        let stored = orientation.storedPixel(
                            column: column,
                            row: row,
                            uprightWidth: uprightWidth,
                            uprightHeight: uprightHeight
                        )
                        let sourceOffset = stored.row * bytesPerRow + stored.column * bytesPerPixel
                        let targetOffset = row * rowLength + column * bytesPerPixel
                        for byte in 0..<bytesPerPixel {
                            target[targetOffset + byte] = source[sourceOffset + byte]
                        }
                    }
                }
            }
        }
        var uprightPixels = withPixels(turned, width: uprightWidth, height: uprightHeight)
        if uprightPixels.pixelDescription["Orientation" as CFString] != nil {
            uprightPixels.pixelDescription["Orientation" as CFString] = 1
        }
        return uprightPixels
    }

    /// One-byte pixels drawn at their size times `scale`, never smaller than one pixel, in rows without padding. Nil
    /// for pixels of any other format, and when Core Graphics cannot draw them.
    func scaled(by scale: Double) -> Self? {
        let scaledWidth = max(Int((Double(width) * scale).rounded()), 1)
        let scaledHeight = max(Int((Double(height) * scale).rounded()), 1)
        return scaled(toWidth: scaledWidth, height: scaledHeight)
    }

    private func scaled(toWidth scaledWidth: Int, height scaledHeight: Int) -> Self? {
        guard isOneByte else { return nil }
        let gray = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 8,
                  bytesPerRow: bytesPerRow,
                  space: gray,
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ),
              let bitmap = CGContext(
                  data: nil,
                  width: scaledWidth,
                  height: scaledHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: gray,
                  bitmapInfo: bitmapInfo.rawValue
              ) else {
            return nil
        }
        bitmap.interpolationQuality = .high
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        guard let rows = bitmap.data else { return nil }
        // The bitmap pads its rows, and an auxiliary image is written without padding.
        var pixels = Data(capacity: scaledWidth * scaledHeight)
        for row in 0..<scaledHeight {
            let start = rows.advanced(by: row * bitmap.bytesPerRow).assumingMemoryBound(to: UInt8.self)
            pixels.append(start, count: scaledWidth)
        }
        return withPixels(pixels, width: scaledWidth, height: scaledHeight)
    }

    /// Bytes of one pixel of the single-plane formats auxiliary images use, nil for any other format.
    private static func bytesPerPixel(of pixelFormat: OSType) -> Int? {
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            1
        case kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_OneComponent16,
             kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DisparityFloat16:
            2
        case kCVPixelFormatType_OneComponent32Float, kCVPixelFormatType_DepthFloat32,
             kCVPixelFormatType_DisparityFloat32, kCVPixelFormatType_32BGRA, kCVPixelFormatType_32ARGB:
            4
        case kCVPixelFormatType_64RGBAHalf:
            8
        default:
            nil
        }
    }
}
