//
//  CameraFlowQualityLevels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the medium and the low quality of a flow mean. Group 1, an app constraint: the user never changes it.
///
/// ```swift
/// let compact = CameraFlowOutputSize.longSide(maximum: 1280)
/// configuration.photoQualityLevels.medium = CameraFlowQualityLevel(size: .original, format: .jpeg(quality: 0.7))
/// configuration.photoQualityLevels.low = CameraFlowQualityLevel(size: compact, format: .jpeg(quality: 0.6))
/// ```
///
/// A level only narrows ``CameraFlowConfiguration/output``, see ``CameraFlowQualityLevel``. The high quality has no
/// level: it is the output itself. The low level need not be smaller than the medium one. The Format panel leaves out
/// a quality whose output is the same as the output of a quality above it.
public struct CameraFlowQualityLevels: Sendable, Hashable {
    /// The medium quality. Default: at most 1920 pixels on the long side (``CameraFlowOutputSize/standard``) in the
    /// format of the output.
    public var medium = CameraFlowQualityLevel(size: .standard)
    /// The low quality. Default: at most 1920 pixels on the long side, a HEIC at a compression quality of 0.5.
    public var low = CameraFlowQualityLevel(size: .standard, format: .heic(quality: 0.5))

    /// Creates the default levels. Change the properties that should differ.
    public init() {}

    /// The level of a quality, nil for the high one, which is the output as the app set it.
    func level(of quality: CameraFlowQuality) -> CameraFlowQualityLevel? {
        switch quality {
        case .high: nil
        case .medium: medium
        case .low: low
        }
    }

    /// Stops the program on a level no photo can meet.
    /// - Precondition: every `longSide(maximum:)` is at least 1, and every compression quality lies in 0...1.
    func validate() {
        medium.validate(name: "medium")
        low.validate(name: "low")
    }
}

/// One quality below the high one: the largest size of a photo, and how the photo is encoded.
///
/// A level narrows the output of the app and never widens it:
/// - The size is the smaller of the level's and the output's. ``CameraFlowOutputSize/original`` keeps the size of the
///   output, so a level may encode the photo again without scaling it.
/// - The format ``CameraFlowOutputFormat/original`` keeps the format of the output. A photo that is scaled down is
///   encoded again in its own type at a compression quality of 0.9.
/// - A format with a compression quality is taken as it is where the output keeps the original format. Where the
///   output names a format, the photo stays in the output's format, at the lower of the two compression qualities.
public struct CameraFlowQualityLevel: Sendable, Hashable {
    /// The largest size of a photo, the short side scaled with the long one. ``CameraFlowOutputSize/original`` keeps
    /// the size of the output. A ``CameraFlowOutputSize/longSide(maximum:)`` is at least 1.
    public var size: CameraFlowOutputSize
    /// How the photo is encoded. Default ``CameraFlowOutputFormat/original``: the format of the output.
    public var format: CameraFlowOutputFormat

    /// A level with a size and a format.
    /// - Parameters:
    ///   - size: The largest size of a photo. A ``CameraFlowOutputSize/longSide(maximum:)`` is at least 1: a flow
    ///     created with a smaller one stops the program.
    ///   - format: How the photo is encoded, with a compression quality in 0...1. Default
    ///     ``CameraFlowOutputFormat/original``, the format of the output.
    public init(size: CameraFlowOutputSize, format: CameraFlowOutputFormat = .original) {
        self.size = size
        self.format = format
    }

    /// The output of this level inside the output of the app.
    func output(within output: CameraFlowOutput) -> CameraFlowOutput {
        var narrowed = output
        narrowed.size = size.narrowed(by: output.size)
        guard let quality = format.compressionQuality else { return narrowed }
        narrowed.format = switch output.format {
        case .original: format
        case let .jpeg(outputQuality): .jpeg(quality: min(outputQuality, quality))
        case let .heic(outputQuality): .heic(quality: min(outputQuality, quality))
        }
        return narrowed
    }

    /// Stops the program on a level no photo can meet.
    /// - Precondition: a `longSide(maximum:)` is at least 1, and a compression quality lies in 0...1.
    func validate(name: String) {
        size.validate(name: "CameraFlowQualityLevels.\(name).size")
        if let quality = format.compressionQuality {
            precondition(
                (0...1).contains(quality),
                "The compression quality of CameraFlowQualityLevels.\(name) lies in 0...1, not \(quality)"
            )
        }
    }
}
