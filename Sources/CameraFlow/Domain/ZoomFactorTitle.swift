//
//  ZoomFactorTitle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// Text of zoom factors as the camera writes them. They stand below the views, since the Camera Control's lens
/// picker writes the current factor too.
enum ZoomFactorTitle {

    /// An inactive lens button: no sign and no leading zero, such as ".5" and "2".
    static func lens(_ factor: CGFloat, locale: Locale) -> String {
        let title = dial(factor, locale: locale)
        let zero = 0.formatted(.number.locale(locale))
        guard factor < 1, title.hasPrefix(zero) else { return title }
        return String(title.dropFirst(zero.count))
    }

    /// The current zoom with its sign, in the form of the flow's language as the stock camera writes it: "0.5×" and
    /// "21.2×" in English, "x2" in Spanish, "2 ×" in Russian.
    static func current(_ factor: CGFloat, localization: FlowLocalization) -> String {
        let title = dial(factor, locale: localization.locale)
        return String(
            localized: "camera.zoom.factor",
            defaultValue: "\(title)×",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// A label on the dial, such as "0.5" and "40". The factor is cut to one decimal, never rounded up.
    static func dial(_ factor: CGFloat, locale: Locale) -> String {
        let truncated = (Double(factor) * 10 + 1e-9).rounded(.down) / 10
        return truncated.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }
}
