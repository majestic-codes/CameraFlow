//
//  TextRuler.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreText
import Foundation
@testable import CameraFlow

/// Measures text in a style of `CameraTextStyle`, the font `CameraTypography` sets it in on the phone. The system
/// font of macOS has the letters of the phone's, so a width here is the width on the phone to within a few percent.
///
/// CoreText asks the font registry of the system for a fallback font over a synchronous connection. Asked from
/// every thread of the concurrency pool at once, those calls never return, so all the measuring goes through one
/// queue, a text at a time.
struct TextRuler: Sendable {
    private static let queue = DispatchQueue(label: "CameraFlowTests.TextRuler")

    /// The share of its room a text may fill, which leaves the few percent the phone may set it wider.
    static let platformMargin: CGFloat = 0.97

    private let style: CameraTextStyle
    private let letterSpacing: CGFloat

    /// A ruler for a style, with the space after every letter that a language takes.
    init(_ style: CameraTextStyle, tracking: LetterTracking) {
        self.style = style
        letterSpacing = tracking.amount(style.tracking)
    }

    /// A ruler for a style whose text is set without the stock tracking, such as an option or a notice.
    init(_ style: CameraTextStyle) {
        self.init(style, letterSpacing: 0)
    }

    /// A ruler for a style with this space after every letter, whatever the language.
    init(_ style: CameraTextStyle, letterSpacing: CGFloat) {
        self.style = style
        self.letterSpacing = letterSpacing
    }

    func width(of text: String) -> CGFloat {
        Self.queue.sync {
            style.width(of: text, letterSpacing: letterSpacing)
        }
    }

    /// The lines a text takes in a column of a width, broken between words as the views break it.
    func lineCount(of text: String, within width: CGFloat) -> Int {
        Self.queue.sync {
            let attributed = style.attributedText(text, letterSpacing: letterSpacing)
            let typesetter = CTTypesetterCreateWithAttributedString(attributed)
            let length = CFAttributedStringGetLength(attributed)
            var start = 0
            var count = 0
            while start < length {
                start += max(CTTypesetterSuggestLineBreak(typesetter, start, Double(width)), 1)
                count += 1
            }
            return count
        }
    }
}
#endif
