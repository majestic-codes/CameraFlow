//
//  PhotoCaptureCapabilities.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The size of the photos a camera takes.
struct PhotoCaptureResolution: Sendable, Equatable {
    /// The megapixel count the flow shoots at where the camera has it, as the stock camera does by default.
    static let preferredMegapixels = 12

    let width: Int32
    let height: Int32

    /// The pixel count of the size in millions, rounded.
    var megapixels: Int {
        Int((Double(width) * Double(height) / 1_000_000).rounded())
    }

    /// Whether the pixel count is within 10% of the preferred one.
    var isPreferred: Bool {
        let pixels = Double(width) * Double(height) / 1_000_000
        let preferred = Double(Self.preferredMegapixels)
        return abs(pixels - preferred) / preferred < 0.1
    }

    /// The size a camera shoots at, out of the photo sizes of its format: the preferred one where the format has it,
    /// its largest otherwise. Nil for a format without photo sizes.
    static func offered(among sizes: [(width: Int32, height: Int32)]) -> Self? {
        let resolutions = sizes.map { Self(width: $0.width, height: $0.height) }
        if let preferred = resolutions.first(where: \.isPreferred) {
            return preferred
        }
        return resolutions.max { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
    }

    /// The smallest of the sizes whose short side reaches `shortSide` and that fit in `limit`: the size a picture
    /// drawn that large needs. Nil when none does.
    static func smallest(
        reaching shortSide: Int32,
        among sizes: [(width: Int32, height: Int32)],
        within limit: Self
    ) -> Self? {
        sizes
            .map { Self(width: $0.width, height: $0.height) }
            .filter { min($0.width, $0.height) >= shortSide && $0.width <= limit.width && $0.height <= limit.height }
            .min { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }
    }
}

/// What the running camera can do for photos.
struct PhotoCaptureCapabilities: Sendable, Equatable {
    let flashModes: [CameraFlowFlashMode]
    let isLivePhotoSupported: Bool
    /// Device limits narrowed to the format's recommended range where the system reports one.
    let exposureBiasRange: ClosedRange<Double>
    let formats: [CameraFlowPhotoFormat]
    /// False when HEIF photos fall back to JPEG.
    let encodesHEVC: Bool
    /// The size every photo is taken at, nil on a camera whose format has no photo sizes.
    let resolution: PhotoCaptureResolution?
    /// What a long press locks at a point (AE/AF Lock), nil on a camera that can lock neither the focus nor the
    /// exposure there.
    let lockableAdjustments: LockableAdjustments?

    /// The same camera with only the costly features a flow can use turned on.
    func narrowed(to features: PhotoCaptureFeatures) -> Self {
        Self(
            flashModes: flashModes,
            isLivePhotoSupported: isLivePhotoSupported && features.livePhoto,
            exposureBiasRange: exposureBiasRange,
            formats: formats.filter { $0 != .raw || features.raw },
            encodesHEVC: encodesHEVC,
            resolution: resolution,
            lockableAdjustments: lockableAdjustments
        )
    }
}
