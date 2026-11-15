//
//  StringCatalog.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation

/// The part of the String Catalog format the checks read, loaded from `Resources/Localizable.xcstrings` of the
/// checkout.
struct StringCatalog: Decodable {
    struct Entry: Decodable {
        let localizations: [String: Localization]
    }

    /// The keys of a localisation in the catalog's JSON.
    private enum LocalizationKey: String, CodingKey {
        case stringUnit
        case variations
    }

    struct Localization: Decodable {
        /// Whether the localisation has a text for each plural category.
        let isPlural: Bool
        /// The units of the localisation by plural category, or its one unit under "other".
        private let units: [String: Unit]

        /// Reads a localisation, which has a text or plural forms: one with neither fails the catalog.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: LocalizationKey.self)
            let stringUnit = try container.decodeIfPresent(Unit.self, forKey: .stringUnit)
            let variations = try container.decodeIfPresent(Variations.self, forKey: .variations)
            isPlural = variations != nil
            if let stringUnit {
                units = ["other": stringUnit]
            } else if let variations {
                units = variations.plural.mapValues(\.stringUnit)
            } else {
                let context = DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "A localisation with neither a text nor plural forms"
                )
                throw DecodingError.dataCorrupted(context)
            }
        }

        /// Every text of the localisation by plural category, or under "other" when it has one text.
        var texts: [String: String] {
            units.mapValues(\.value)
        }

        /// The translation state of every text, by the same keys.
        var states: [String: String] {
            units.mapValues(\.state)
        }
    }

    struct Variations: Decodable {
        let plural: [String: PluralForm]
    }

    struct PluralForm: Decodable {
        let stringUnit: Unit
    }

    struct Unit: Decodable {
        let state: String
        let value: String
    }

    enum Failure: Error {
        case noText(key: String, language: String)
    }

    /// The languages the package ships, as the catalog and the `.lproj` folders name them. English is the source.
    static let languages: Set<String> = [
        "ar", "bg", "cs", "da", "de", "el", "en", "es", "es-419", "et", "fi", "fr", "he", "hi", "hr", "hu", "id",
        "it", "ja", "ko", "lt", "lv", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sv", "th", "tr", "uk",
        "vi", "zh-Hans", "zh-Hant"
    ]

    let sourceLanguage: String
    let strings: [String: Entry]

    private static let loaded = Result {
        let url = try SourceTree.checkout().directory.appendingPathComponent("Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    /// The catalog of the checkout, read once for all the tests.
    static func checkout() throws -> Self {
        try loaded.get()
    }

    /// The text of a key in a language: its only one, or the one for many things where it has plural forms.
    func text(_ key: String, in language: String) throws -> String {
        guard let text = strings[key]?.localizations[language]?.texts["other"] else {
            throw Failure.noText(key: key, language: language)
        }
        return text
    }
}
#endif
