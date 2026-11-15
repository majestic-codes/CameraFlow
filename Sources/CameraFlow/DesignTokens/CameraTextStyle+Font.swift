//
//  CameraTextStyle+Font.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The font of a text style and the width of a text set in it. The system font comes from the platform's own
/// factory, so a weight is the one the views get. The tests measure on macOS, whose system font has the letters of
/// the phone's.
extension CameraTextStyle {
    /// Tag of the width axis of the system font, the four characters "wdth".
    private static let widthAxisTag = 0x7764_7468
    /// Character variants of the system font: the slashed zero and the open four.
    private static let characterVariantTags = ["cv08", "cv02"]

    /// The system font of the style with the slashed zero and the open four, narrowed along its width axis where
    /// the style gives one.
    func makeFont() -> CTFont {
        let base = systemFont()
        let features: [[CFString: Any]] = Self.characterVariantTags.map { tag in
            [kCTFontOpenTypeFeatureTag: tag, kCTFontOpenTypeFeatureValue: 1]
        }
        var attributes: [CFString: Any] = [kCTFontFeatureSettingsAttribute: features]
        if let widthAxis {
            // The base font carries its weight as a variation, which a new variation dictionary would replace.
            var variation = CTFontCopyVariation(base) as? [Int: CGFloat] ?? [:]
            variation[Self.widthAxisTag] = widthAxis
            attributes[kCTFontVariationAttribute] = variation
        }
        let baseDescriptor = CTFontCopyFontDescriptor(base)
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(baseDescriptor, attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// The width of a line of text set in the style, with the space after every letter that the language takes.
    func width(of text: String, tracking: LetterTracking) -> CGFloat {
        width(of: text, letterSpacing: tracking.amount(self.tracking))
    }

    /// The width of a line of text set in the style, with this space after every letter.
    func width(of text: String, letterSpacing: CGFloat) -> CGFloat {
        let line = CTLineCreateWithAttributedString(attributedText(text, letterSpacing: letterSpacing))
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    /// A text set in the style, with this space after every letter, for CoreText to lay out.
    func attributedText(_ text: String, letterSpacing: CGFloat) -> CFAttributedString {
        let attributes: [CFString: Any] = [kCTFontAttributeName: makeFont(), kCTKernAttributeName: letterSpacing]
        guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else {
            preconditionFailure("CameraFlow: CoreText could not hold the text “\(text)”")
        }
        return attributed
    }

    private func systemFont() -> CTFont {
        #if canImport(UIKit)
        let weight = UIFont.Weight(self.weight)
        let font = if monospacedDigits {
            UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        } else {
            UIFont.systemFont(ofSize: size, weight: weight)
        }
        #elseif canImport(AppKit)
        let weight = NSFont.Weight(self.weight)
        let font = if monospacedDigits {
            NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        } else {
            NSFont.systemFont(ofSize: size, weight: weight)
        }
        #endif
        return font as CTFont
    }
}
