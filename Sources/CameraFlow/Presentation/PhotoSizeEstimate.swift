//
//  PhotoSizeEstimate.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The approximate size of the file of one photo the app receives, as the Format panel writes it under its options.
///
/// This is an estimate, not a measurement: the size of a compressed photo depends on what is in the picture, and a
/// plain wall takes a fraction of what foliage does. The estimate is the pixel count of the frame the app receives
/// times a typical number of bytes per pixel for the way that frame is encoded. A Live Photo's movie and the copy
/// with the second camera's circle are not counted.
///
/// The bytes per pixel were measured with ImageIO on four iPhone photos (three of 12 MP and one of 24 MP, encoded
/// again at each quality on macOS 27) and rounded. The camera's own HEIF files of those photos averaged 0.17, which
/// is Apple's "2 MB for 12 MP". The camera's JPEG and Apple ProRAW figures are Apple's: about twice the HEIF, and
/// 25 MB for 12 MP.
struct PhotoSizeEstimate: Equatable, Sendable {
    /// The frame the camera delivers, in pixels.
    let cameraFrame: CGSize
    let aspectRatio: CameraFlowAspectRatio
    let format: CameraFlowPhotoFormat
    /// False on a camera whose HEIF photos fall back to JPEG.
    let encodesHEVC: Bool
    /// The output the photo is brought to.
    let output: CameraFlowOutput

    /// Bytes per pixel of a photo as the camera writes it.
    enum CameraBytesPerPixel {
        static let heif = 0.17
        static let jpeg = 0.35
        static let appleProRAW = 2.1
    }

    /// Bytes per pixel of a frame of the camera's size encoded again by ImageIO, by compression quality.
    enum EncodedBytesPerPixel {
        static let heic: [(quality: Double, bytesPerPixel: Double)] = [
            (0.1, 0.01), (0.3, 0.03), (0.5, 0.065), (0.7, 0.145), (0.8, 0.16), (0.9, 0.205), (1, 0.7)
        ]
        static let jpeg: [(quality: Double, bytesPerPixel: Double)] = [
            (0.1, 0.04), (0.3, 0.055), (0.5, 0.11), (0.7, 0.195), (0.8, 0.23), (0.9, 0.29), (1, 0.53)
        ]
        /// A frame scaled down holds more detail in every pixel and takes this many times the bytes per pixel.
        static let scaledDownFactor = 1.3
    }

    /// The frame of the camera cut to the aspect ratio. A RAW photo is never cut.
    private var framedSize: CGSize {
        guard format != .raw else { return cameraFrame }
        let width = Int(cameraFrame.width)
        let height = Int(cameraFrame.height)
        return PhotoCaptureCropper.cropRectangle(width: width, height: height, aspectRatio: aspectRatio).size
    }

    /// How much smaller the output's size limit makes each side of the framed photo, 1 when it fits.
    private var scale: Double {
        let longSide = Double(max(framedSize.width, framedSize.height))
        guard format != .raw, let maximum = output.size.maximumLongSide, longSide > Double(maximum) else { return 1 }
        return Double(maximum) / longSide
    }

    /// The pixels of the photo the app receives.
    var pixelCount: Double {
        Double(framedSize.width) * Double(framedSize.height) * scale * scale
    }

    /// The bytes one pixel of the photo takes in its file.
    var bytesPerPixel: Double {
        guard format != .raw else { return CameraBytesPerPixel.appleProRAW }
        let isCropped = framedSize != cameraFrame
        let isScaled = scale < 1
        guard isCropped || isScaled || output.format != .original || output.metadata == .stripped else {
            return encodesHEVC ? CameraBytesPerPixel.heif : CameraBytesPerPixel.jpeg
        }
        let table = switch output.format {
        case .jpeg: EncodedBytesPerPixel.jpeg
        case .heic: EncodedBytesPerPixel.heic
        case .original: encodesHEVC ? EncodedBytesPerPixel.heic : EncodedBytesPerPixel.jpeg
        }
        let quality = output.format.compressionQuality ?? ImageEncoding.defaultCompressionQuality
        let encoded = Self.interpolated(table, at: quality)
        return isScaled ? encoded * EncodedBytesPerPixel.scaledDownFactor : encoded
    }

    /// The approximate size of the file in bytes.
    var byteCount: Int {
        Int((pixelCount * bytesPerPixel).rounded())
    }

    /// The bytes per pixel at a quality: on the line between the two measured qualities around it, and the first
    /// or the last measured value outside them.
    private static func interpolated(
        _ table: [(quality: Double, bytesPerPixel: Double)],
        at quality: Double
    ) -> Double {
        guard let first = table.first, let last = table.last else {
            preconditionFailure("A table of bytes per pixel has no measured quality")
        }
        guard quality > first.quality else { return first.bytesPerPixel }
        guard let upperIndex = table.firstIndex(where: { $0.quality >= quality }) else { return last.bytesPerPixel }
        let lower = table[upperIndex - 1]
        let upper = table[upperIndex]
        let fraction = (quality - lower.quality) / (upper.quality - lower.quality)
        return lower.bytesPerPixel + (upper.bytesPerPixel - lower.bytesPerPixel) * fraction
    }
}

extension PhotoSizeEstimate {
    /// The estimate for the next photo of the camera, nil until the camera has started and offers a size.
    @MainActor
    init?(settings: PhotoSettingsModel) {
        guard let frame = settings.effectivePhotoFrame else { return nil }
        self.init(
            cameraFrame: CGSize(width: Int(frame.width), height: Int(frame.height)),
            aspectRatio: settings.aspectRatio,
            format: settings.effectivePhotoFormat,
            encodesHEVC: settings.encodesHEVC,
            output: settings.output
        )
    }
}
