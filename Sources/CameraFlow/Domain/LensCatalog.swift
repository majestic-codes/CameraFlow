//
//  LensCatalog.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Zoom data read from a capture device, in the device's own zoom units.
struct LensOptics: Sendable, Equatable {
    /// One physical lens of the device.
    struct PhysicalLens: Sendable, Equatable {
        /// Device zoom factor at which this lens takes over. The widest lens has 1.
        let deviceFactor: CGFloat
        /// Zoom factors, relative to this lens, at which the sensor still delivers native resolution.
        let cropFactors: [CGFloat]
        let focalLength: Int?
    }

    let lenses: [PhysicalLens]
    /// Multiplies a device zoom factor into the displayed one, 0.5 when the widest lens is the ultra wide.
    let displayMultiplier: CGFloat
    let maximumDeviceFactor: CGFloat
    /// The top of the zoom range the system recommends for the format, which the Camera Control's zoom slider
    /// spans. Nil where the system recommends none.
    let recommendedMaximumDeviceFactor: CGFloat?
}

/// Builds the lens buttons and the dial range from the device's zoom data.
///
/// A lens gets a button, and so does a native-resolution crop of it when the crop lands on a whole factor
/// below the next lens. The ultra wide camera of an iPhone 17 Pro reports a crop at 0.8, which the stock
/// camera does not show. The dial reaches as far as the zoom range the system recommends, which the Camera
/// Control's slider spans, or five times the longest lens where there is none, and always the longest lens.
enum LensCatalog {
    /// Digital zoom offered beyond the longest lens button.
    private static let digitalReach: CGFloat = 5
    /// Focal length of a main camera that also offers the 28 mm and 35 mm framings.
    private static let mainFocalLength = 24
    private static let mainFramingFactors: [CGFloat] = [1.2, 1.5]

    static func capabilities(position: CameraPosition, optics: LensOptics) -> CameraCapabilities {
        let multiplier = optics.displayMultiplier
        let primaryFactors = optics.lenses.map { $0.deviceFactor * multiplier }
        let maximumFactor = optics.maximumDeviceFactor * multiplier
        var lenses: [CameraLens] = []
        for (index, physicalLens) in optics.lenses.enumerated() {
            let factor = primaryFactors[index]
            let nextFactor = index + 1 < primaryFactors.count ? primaryFactors[index + 1] : maximumFactor
            lenses.append(CameraLens(factor: factor, focalLength: physicalLens.focalLength))
            let crops = physicalLens.cropFactors
                .map { factor * $0 }
                .filter { $0 > factor && $0 < nextFactor && $0 == $0.rounded() }
            lenses += crops.map { CameraLens(factor: $0, focalLength: nil) }
        }
        lenses.sort { $0.factor < $1.factor }
        let lowest = lenses.first?.factor ?? 1
        let longest = lenses.last?.factor ?? 1
        let reach = optics.recommendedMaximumDeviceFactor.map { min($0, optics.maximumDeviceFactor) * multiplier }
            ?? min(maximumFactor, longest * digitalReach)
        let highest = max(reach, longest, lowest)
        return CameraCapabilities(
            position: position,
            lenses: lenses,
            zoomRange: lowest...highest,
            markedFactors: markedFactors(lenses: lenses)
        )
    }

    private static func markedFactors(lenses: [CameraLens]) -> [CGFloat] {
        guard let mainIndex = lenses.firstIndex(where: { $0.factor == 1 }) else { return [] }
        guard lenses[mainIndex].focalLength == mainFocalLength else { return [] }
        let nextIndex = mainIndex + 1
        guard nextIndex < lenses.count else { return mainFramingFactors }
        return mainFramingFactors.filter { $0 < lenses[nextIndex].factor }
    }
}
