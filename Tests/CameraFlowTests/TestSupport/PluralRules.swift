//
//  PluralRules.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
/// The plural categories CLDR gives the cardinal numbers of each language of the package, each with a whole
/// number that falls in it. A category that only fractions fall in has no number.
enum PluralRules {
    private static let families: [(languages: [String], samples: [String: Int?])] = [
        (["bg", "da", "de", "el", "en", "et", "fi", "hi", "hu", "nb", "nl", "sv", "tr"], ["one": 1, "other": 2]),
        (["es", "es-419", "fr", "it", "pt-BR", "pt-PT"], ["one": 1, "many": 1_000_000, "other": 2]),
        (["ru", "uk"], ["one": 21, "few": 3, "many": 5, "other": nil]),
        (["pl"], ["one": 1, "few": 2, "many": 5, "other": nil]),
        (["cs", "sk"], ["one": 1, "few": 2, "many": nil, "other": 5]),
        (["lt"], ["one": 21, "few": 2, "many": nil, "other": 10]),
        (["hr"], ["one": 21, "few": 2, "other": 5]),
        (["ro"], ["one": 1, "few": 2, "other": 20]),
        (["lv"], ["zero": 0, "one": 21, "other": 2]),
        (["he"], ["one": 1, "two": 2, "other": 3]),
        (["ar"], ["zero": 0, "one": 1, "two": 2, "few": 3, "many": 11, "other": 100]),
        (["id", "ja", "ko", "th", "vi", "zh-Hans", "zh-Hant"], ["other": 5])
    ]

    /// A number of each category of a language, by the category.
    static let samples: [String: [String: Int?]] = families.reduce(into: [:]) { samples, family in
        for language in family.languages {
            samples[language] = family.samples
        }
    }

    /// The categories of a language, empty for one the package does not ship.
    static func categories(of language: String) -> Set<String> {
        Set((samples[language] ?? [:]).keys)
    }
}
#endif
