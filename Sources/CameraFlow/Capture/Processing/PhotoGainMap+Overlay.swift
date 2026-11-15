//
//  PhotoGainMap+Overlay.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO

extension PhotoGainMap {
    /// Why a gain map cannot go under an overlay. The text names the gain map and the reason.
    struct OverlayFailure: Error, Equatable, CustomStringConvertible {
        let description: String
    }

    /// The gain map ready to go under an overlay: its one-byte pixels and the level of no boost. Fails for pixels
    /// that cannot be read or have more than one byte, and for a gain map whose level of no boost is unknown.
    func underOverlay() -> Result<GainMapUnderOverlay, OverlayFailure> {
        let pixels: AuxiliaryPixels
        do {
            pixels = try AuxiliaryPixels(info: info, type: type)
        } catch {
            return .failure(OverlayFailure(description: error.description))
        }
        guard pixels.isOneByte else {
            return .failure(OverlayFailure(description: "\(type) has more than one byte a pixel"))
        }
        return noBoostLevel().map { level in
            GainMapUnderOverlay(gainMap: self, pixels: pixels, noBoostLevel: level)
        }
    }

    /// The level of a pixel that leaves the photo as it is. Apple's gain map boosts the photo by its level, so 0 is no
    /// boost. A level of the ISO gain map, raised to the reciprocal of the gamma of its metadata, places a gain in
    /// stops between the minimum and the maximum of its metadata, and no boost is a gain of 0 stops.
    func noBoostLevel() -> Result<UInt8, OverlayFailure> {
        if type == kCGImageAuxiliaryDataTypeHDRGainMap {
            return .success(0)
        }
        if #available(iOS 18, macOS 15, *), type == kCGImageAuxiliaryDataTypeISOGainMap {
            return isoNoBoostLevel()
        }
        return .failure(OverlayFailure(description: "\(type) is no gain map"))
    }

    private func isoNoBoostLevel() -> Result<UInt8, OverlayFailure> {
        guard let value = info[kCGImageAuxiliaryDataInfoMetadata] as CFTypeRef?,
              CFGetTypeID(value) == CGImageMetadataGetTypeID() else {
            return .failure(OverlayFailure(description: "\(type) has no metadata"))
        }
        let metadata = unsafeDowncast(value, to: CGImageMetadata.self)
        let channels = CGImageMetadataCopyTagWithPath(metadata, nil, "HDRToneMap:ChannelMetadata" as CFString)
        let channelCount = channels.flatMap { CGImageMetadataTagCopyValue($0) as? [Any] }?.count
        guard channelCount == 1 else {
            return .failure(OverlayFailure(description: "\(type) has no metadata of one channel"))
        }
        let channel = "HDRToneMap:ChannelMetadata[0].HDRToneMap:"
        guard let minimum = Self.number(at: channel + "GainMapMin", in: metadata),
              let maximum = Self.number(at: channel + "GainMapMax", in: metadata),
              let gamma = Self.number(at: channel + "Gamma", in: metadata),
              gamma > 0, maximum >= minimum else {
            return .failure(OverlayFailure(description: "\(type) has no readable gain range"))
        }
        // Every level of a gain map without a range is the same gain.
        guard maximum > minimum else { return .success(0) }
        let noBoost = min(max(-minimum / (maximum - minimum), 0), 1)
        return .success(UInt8((pow(noBoost, gamma) * 255).rounded()))
    }

    private static func number(at path: String, in metadata: CGImageMetadata) -> Double? {
        let text = CGImageMetadataCopyStringValueWithPath(metadata, nil, path as CFString)
        return text.flatMap { Double($0 as String) }
    }
}

/// A gain map an overlay goes over, with the level of its pixels that leaves the photo as it is.
struct GainMapUnderOverlay {
    let gainMap: PhotoGainMap
    let pixels: AuxiliaryPixels
    let noBoostLevel: UInt8

    /// The gain map with every pixel the overlay covers brought to no boost, as far as the overlay covers it, so an
    /// HDR screen shows the overlay as it was drawn. How far the overlay covers the gain map is taken from
    /// `coverages`, which draws the overlay at the gain map's size the first time a gain map of that size asks.
    func neutralized(
        under coverages: inout OverlayCoverages,
        drawingOverlay drawOverlay: OverlayDrawing
    ) async throws -> PhotoGainMap {
        let width = pixels.width
        let coverage = try await coverages.levels(width: width, height: pixels.height, drawingOverlay: drawOverlay)
        let noBoost = Int(noBoostLevel)
        var levels = Data(count: width * pixels.height)
        levels.withUnsafeMutableBytes { target in
            pixels.data.withUnsafeBytes { source in
                for row in 0..<pixels.height {
                    for column in 0..<width {
                        let level = Int(source[row * pixels.bytesPerRow + column])
                        let covered = Int(coverage[row * width + column])
                        let blended = (level * (255 - covered) + noBoost * covered + 127) / 255
                        target[row * width + column] = UInt8(blended)
                    }
                }
            }
        }
        let neutralized = pixels.withLevels(levels)
        return PhotoGainMap(type: gainMap.type, info: neutralized.replacingPixels(in: gainMap.info))
    }
}

/// How far an overlay covers each pixel of bitmaps of the sizes the gain maps of a photo have, drawn once for each
/// size: the gain maps of a photo usually share theirs.
struct OverlayCoverages {
    private struct Coverage {
        let width: Int
        let height: Int
        let levels: [UInt8]
    }

    private var drawn: [Coverage] = []

    /// The alpha of the overlay drawn alone over a clear bitmap of the size, which `drawOverlay` draws it into: one
    /// level a pixel, rows from the top.
    mutating func levels(width: Int, height: Int, drawingOverlay drawOverlay: OverlayDrawing) async throws -> [UInt8] {
        if let known = drawn.first(where: { $0.width == width && $0.height == height }) {
            return known.levels
        }
        let levels = try await Self.drawnLevels(width: width, height: height, drawingOverlay: drawOverlay)
        drawn.append(Coverage(width: width, height: height, levels: levels))
        return levels
    }

    private static func drawnLevels(
        width: Int,
        height: Int,
        drawingOverlay drawOverlay: OverlayDrawing
    ) async throws -> [UInt8] {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
              let bitmap = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw OverlayCopyFailure.cannotCreateBitmap(width: width, height: height)
        }
        try await drawOverlay(bitmap, CGSize(width: width, height: height))
        guard let data = bitmap.data else {
            throw OverlayCopyFailure.cannotCreateBitmap(width: width, height: height)
        }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = bitmap.bytesPerRow
        var levels = [UInt8](repeating: 0, count: width * height)
        for row in 0..<height {
            for column in 0..<width {
                levels[row * width + column] = bytes[row * bytesPerRow + column * 4 + 3]
            }
        }
        return levels
    }
}
