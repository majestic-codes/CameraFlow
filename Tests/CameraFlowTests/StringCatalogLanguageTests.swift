//
//  StringCatalogLanguageTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

/// Every translation of `Localizable.xcstrings`, one language at a time: it is finished, it has the plural forms
/// of its language, it takes the arguments of the English text, and it is a text of its own.
@Suite("String Catalog translations")
struct StringCatalogLanguageTests {
    /// A format argument of a text, with the position it names if it names one.
    private struct Argument: Equatable {
        let position: Int?
        let type: String
    }

    static let languages = StringCatalog.languages.sorted()

    /// The keys whose text is the English one in some languages, because the language writes the word, the name
    /// or the unit the same way.
    private static let sameAsEnglish: [String: Set<String>] = [
        "camera.control.focus": ["nl"],
        "camera.control.livePhoto": [
            "bg", "cs", "da", "de", "el", "es", "es-419", "et", "fi", "fr", "hi", "hr", "hu", "id", "it", "lt", "lv",
            "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "ru", "sv", "th", "tr", "uk", "vi"
        ],
        "camera.control.shutter.stopTimer": ["da", "nl"],
        "camera.control.timer": ["da", "de", "id", "it", "nl", "pt-BR", "sv"],
        "camera.flashDisabled.ok": [
            "cs", "da", "de", "el", "es", "es-419", "et", "fi", "fr", "hr", "hu", "it", "ja", "nb", "nl", "pl", "pt-BR",
            "pt-PT", "ro", "ru", "sk", "sv", "uk", "vi"
        ],
        "camera.quality.medium.mark": ["es", "es-419", "it", "ro", "sv"],
        "camera.save.album": ["hr", "id", "it", "vi"],
        "camera.setting.aspect": ["ro"],
        "camera.setting.dualCamera": ["es-419", "ro"],
        "camera.setting.flash": ["es", "es-419", "fr", "it", "pt-BR", "pt-PT"],
        "camera.setting.format": ["da", "de", "fr", "hr", "id", "nb", "pl", "ro", "sv"],
        "camera.setting.live": [
            "bg", "cs", "da", "de", "el", "es", "es-419", "et", "fi", "fr", "he", "hu", "id", "it", "ja", "ko", "lt",
            "lv", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "sk", "sv", "th", "vi"
        ],
        "camera.setting.timer": ["da", "de", "id", "it", "nl", "pt-BR", "sv"],
        "camera.value.auto": ["fr", "nb", "nl", "ro", "sv"],
        "camera.value.seconds": ["nl", "vi"],
        "camera.zoom.focalLength": [
            "ar", "bg", "cs", "da", "de", "el", "es", "es-419", "et", "fi", "fr", "he", "hi", "hr", "hu", "id", "it",
            "ja", "ko", "lt", "lv", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro", "sk", "sv", "th", "tr", "vi", "zh-Hans",
            "zh-Hant"
        ],
        "camera.zoom.factor": [
            "bg", "cs", "da", "de", "el", "es-419", "et", "fi", "fr", "hi", "hr", "hu", "id", "it", "ja", "ko", "lv",
            "nl", "pl", "pt-BR", "pt-PT", "ro", "sk", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"
        ],
        "camera.zoom.label": ["da", "es", "es-419", "fr", "id", "it", "nb", "nl", "pl", "pt-BR", "pt-PT", "ro"],
        "flow.mode.shooting": ["nl"],
        "flow.review.photo": ["fr"]
    ]

    private let catalog: StringCatalog

    init() throws {
        catalog = try StringCatalog.checkout()
    }

    private static func arguments(of text: String) -> [Argument] {
        text.matches(of: #/%(?:(\d+)\$)?(lld|@)/#).map { match in
            Argument(position: match.1.flatMap { Int($0) }, type: String(match.2))
        }
    }

    private enum Failure: Error {
        /// Only some arguments of the text name a position, or the positions are not one for each argument.
        case brokenPositions(String)
    }

    /// The types of the arguments in the order the code passes them.
    private static func argumentTypes(of text: String) throws -> [String] {
        let arguments = arguments(of: text)
        let positioned = arguments.compactMap { argument in
            argument.position.map { (position: $0, type: argument.type) }
        }
        guard positioned.isEmpty == false else {
            return arguments.map(\.type)
        }
        let positions = positioned.map(\.position)
        guard positioned.count == arguments.count, positions.sorted() == Array(1...arguments.count) else {
            throw Failure.brokenPositions(text)
        }
        return positioned.sorted { $0.position < $1.position }.map(\.type)
    }

    private func localization(_ key: String, in language: String) throws -> StringCatalog.Localization {
        try #require(catalog.strings[key]?.localizations[language], "\(key) in \(language)")
    }

    @Test("Every text is marked as translated", arguments: languages)
    func states(language: String) throws {
        for key in catalog.strings.keys {
            let states = try localization(key, in: language).states
            #expect(states.values.allSatisfy { $0 == "translated" }, "\(key): \(states)")
        }
    }

    @Test("A key with plural forms in English has exactly the CLDR categories of the language", arguments: languages)
    func pluralCategories(language: String) throws {
        let categories = PluralRules.categories(of: language)
        #expect(categories.isEmpty == false)
        for key in catalog.strings.keys {
            let localization = try localization(key, in: language)
            let isPluralInEnglish = try self.localization(key, in: "en").isPlural
            #expect(localization.isPlural == isPluralInEnglish, "\(key)")
            if localization.isPlural {
                #expect(Set(localization.texts.keys) == categories, "\(key)")
            }
        }
    }

    @Test("Every text takes the arguments of the English text: as many, of the same types", arguments: languages)
    func arguments(language: String) throws {
        for key in catalog.strings.keys {
            let english = try catalog.text(key, in: "en")
            let expected = try Self.argumentTypes(of: english)
            for (category, text) in try localization(key, in: language).texts {
                #expect(try Self.argumentTypes(of: text) == expected, "\(key), \(category): \(text)")
                let withoutArguments = text.replacing(#/%(?:\d+\$)?(?:lld|@)/#, with: "")
                #expect(withoutArguments.contains("%") == false, "\(key), \(category): \(text)")
            }
        }
    }

    @Test("No text is empty or has white space around it", arguments: languages)
    func whitespace(language: String) throws {
        for key in catalog.strings.keys {
            for (category, text) in try localization(key, in: language).texts {
                #expect(text.isEmpty == false, "\(key), \(category)")
                #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines), "\(key), \(category)")
                #expect(text.contains("\n") == false, "\(key), \(category)")
            }
        }
    }

    @Test(
        "A translation differs from the English text, but for the words a language shares with English",
        arguments: languages.filter { $0 != "en" }
    )
    func ownText(language: String) throws {
        for key in catalog.strings.keys {
            let english = try localization(key, in: "en").texts
            let texts = try localization(key, in: language).texts
            let isSame = texts.allSatisfy { english.values.contains($0.value) }
            let mayBeSame = Self.sameAsEnglish[key]?.contains(language) ?? false
            #expect(isSame == mayBeSame, "\(key): \(texts.values.sorted())")
        }
    }

    @Test("The list of texts that may equal the English names keys and languages of the catalog only")
    func allowList() {
        for (key, languages) in Self.sameAsEnglish {
            #expect(catalog.strings[key] != nil, "\(key)")
            #expect(languages.isSubset(of: StringCatalog.languages), "\(key)")
        }
    }
}
#endif
