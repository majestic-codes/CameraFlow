//
//  SimulatorImageIO.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing

/// What the ImageIO of an iOS simulator does not do as on macOS and on a device, measured on the iOS 26.1 simulator
/// with small programs that call ImageIO alone, the same calls passing on macOS. A test that needs one of them is
/// skipped on a simulator with `.needsDeviceImageIO(_:)`, which names the gap in the skip, and runs everywhere else.
enum SimulatorImageIOGap: String {
    /// `kCGImageDestinationEncodeToISOGainmap`: `CGImageDestinationFinalize` returns false for a HEIC of an image
    /// with content headroom, so no fixture with an ISO gain map can be made.
    case isoGainMapEncoding = "The simulator's ImageIO cannot encode a HEIC with an ISO gain map"

    /// A 10-bit HEIC added with `CGImageDestinationAddImageFromSource` does not finalize, scaled or not.
    case tenBitHEICReencoding = "The simulator's ImageIO cannot encode a 10-bit HEIC again from its source"

    /// A JPEG scaled with `kCGImageDestinationImageMaxPixelSize` loses its MakerApple keys and gets other EXIF and
    /// TIFF values, and a JPEG written as a HEIC loses XMP tags it keeps on a device.
    case jpegMetadataCopy = "The simulator's ImageIO does not carry every metadata key of a JPEG into a copy"

    /// The HEVC decoder of the simulator rounds the short side of a scaled HEIC thumbnail one pixel lower: 89 x 66
    /// where macOS and a device make 89 x 67.
    case heicThumbnailRounding = "The simulator's ImageIO rounds the short side of a scaled HEIC down"

    /// A DNG read with its type hint gives the size and the pixels of its preview, not of its RAW image: the
    /// simulator has no RAW decoder.
    case rawDecoding = "The simulator's ImageIO has no RAW decoder for a DNG"

    /// Whether the tests run on a simulator.
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

extension Trait where Self == ConditionTrait {

    /// Skips a test on a simulator, whose ImageIO lacks what the test checks, with the gap as the reason.
    static func needsDeviceImageIO(_ gap: SimulatorImageIOGap) -> Self {
        .disabled(if: SimulatorImageIOGap.isSimulator, Comment(rawValue: gap.rawValue))
    }
}
