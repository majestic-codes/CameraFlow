//
//  LetterTracking.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// The space the chrome adds after every letter of its capitals, by the language its texts are written in.
/// The stock camera decides it per language and sets the capitals of a few languages solid, among them Arabic,
/// Hindi and Thai.
struct LetterTracking: Equatable {
    /// The languages whose stock texts turn the letter spacing off (`USE_LETTER_SPACING` of the stock camera):
    /// Arabic, Bengali, Hindi, Malayalam, Punjabi, Tamil and Thai.
    private static let untrackedLanguages: Set<String> = ["ar", "bn", "hi", "ml", "pa", "ta", "th"]

    /// Whether the capitals take the stock space after every letter.
    let isTracked: Bool

    /// The tracking in a language, named as a localisation is, such as "ar" or "zh-Hans".
    init(language: String) {
        let code = Locale.Language(identifier: language).languageCode?.identifier
        isTracked = code.map { Self.untrackedLanguages.contains($0) == false } ?? true
    }

    /// The tracking in the localisation the flow's texts come from, which is not always the language of the device.
    init(_ localization: FlowLocalization) {
        self.init(language: localization.localizationName)
    }

    /// The space after every letter: the stock amount, or none in a language the stock camera sets solid.
    func amount(_ stock: CGFloat) -> CGFloat {
        isTracked ? stock : 0
    }
}
