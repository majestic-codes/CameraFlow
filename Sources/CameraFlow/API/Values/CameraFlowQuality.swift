//
//  CameraFlowQuality.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The quality of the photos the app receives, as the user picks it on the camera's Format panel. Group 2, a user
/// setting: see ``CameraFlowConfiguration/photoQuality``.
///
/// A quality narrows ``CameraFlowConfiguration/output`` and never widens it: the output stays the most the app takes,
/// and a quality gives that or less. It applies to every photo taken after it is chosen, to every photo picked from
/// the library after it is chosen while the picks share the camera's output
/// (``CameraFlowLibraryOutput/sameAsCamera``), and to the copy with a drawing of such a photo. The copy of a camera
/// photo in the system photo library is never touched. Whether the user picks the quality at all is
/// ``CameraFlowConfiguration/photoQuality``: a fixed setting has no row on the screen.
///
/// What ``medium`` and ``low`` give is the app's to say, in ``CameraFlowConfiguration/photoQualityLevels``. The
/// Format panel offers a quality only when its output differs from the output of every quality above it. With the
/// default levels under an output of 1920 pixels ``medium`` is ``high``, so the row has High and Low, and under an
/// output that is already that small and that compressed there is nothing to choose and the row is not shown. RAW
/// can be chosen with ``high`` only, since a DNG cannot be scaled or encoded again: under another quality it stays on
/// the panel dimmed.
///
/// The raw values are what the flow remembers and the app stores in ``CameraFlowPreferences``.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowQuality: String, Codable, Sendable, Hashable, CaseIterable {
    /// The output as the app set it, with no level of its own.
    case high
    /// The medium level of ``CameraFlowQualityLevels``. By default at most 1920 pixels on the long side, so
    /// 1920 x 1440 for a 4:3 photo, in the format of the output.
    case medium
    /// The low level of ``CameraFlowQualityLevels``. By default at most 1920 pixels on the long side and a stronger
    /// compression: a HEIC at a quality of 0.5 where the output keeps the original format, and otherwise the
    /// output's own format at 0.5 or at its own quality when that is lower.
    case low

    /// The output of this quality inside the output of the app, with the levels the app gave.
    func output(within output: CameraFlowOutput, levels: CameraFlowQualityLevels) -> CameraFlowOutput {
        guard let level = levels.level(of: self) else { return output }
        return level.output(within: output)
    }

    /// The qualities that differ inside an output, best first: the output of each differs from the output of every
    /// one before it. The Format panel has its quality row when there are at least two.
    @_spi(Testing)
    public static func distinct(within output: CameraFlowOutput, levels: CameraFlowQualityLevels) -> [Self] {
        var outputs: [CameraFlowOutput] = []
        return allCases.filter { quality in
            let narrowed = quality.output(within: output, levels: levels)
            guard !outputs.contains(narrowed) else { return false }
            outputs.append(narrowed)
            return true
        }
    }

    /// The best quality that gives the same output as this one inside an output: the first one above it with that
    /// output, which the Format panel offers in its place, or else itself.
    func offered(within output: CameraFlowOutput, levels: CameraFlowQualityLevels) -> Self {
        let narrowed = self.output(within: output, levels: levels)
        let better = Self.allCases.prefix { $0 != self }
        return better.first { $0.output(within: output, levels: levels) == narrowed } ?? self
    }
}
