//
//  LocalizedBundleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing
@testable import CameraFlow

/// The compiled resources of the package: the bundle has every language of the catalog, and a text looked up in
/// the bundle of a language is the one the catalog has, in the plural form the number asks for.
@Suite("Localised resources of the bundle")
struct LocalizedBundleTests {
    static let languages = StringCatalog.languages.sorted()

    private let catalog: StringCatalog

    init() throws {
        catalog = try StringCatalog.checkout()
    }

    /// The bundle of one language inside the bundle of the package.
    private func bundle(of language: String) throws -> Bundle {
        let path = try #require(Bundle.module.path(forResource: language, ofType: "lproj"), "\(language).lproj")
        return try #require(Bundle(path: path))
    }

    @Test("The bundle of the package has the languages of the catalog, with English as its development language")
    func bundleLanguages() {
        #expect(Set(Bundle.module.localizations) == StringCatalog.languages)
        #expect(Bundle.module.developmentLocalization == "en")
    }

    @Test("A text without plural forms comes out of the bundle as the catalog has it", arguments: languages)
    func texts(language: String) throws {
        let bundle = try bundle(of: language)
        for (key, entry) in catalog.strings {
            let localization = try #require(entry.localizations[language], "\(key)")
            guard localization.isPlural == false else { continue }
            let found = bundle.localizedString(forKey: key, value: "missing", table: nil)
            #expect(found == localization.texts["other"], "\(key)")
        }
    }

    @Test("A number picks the plural form of its CLDR category", arguments: languages)
    func pluralForms(language: String) throws {
        let bundle = try bundle(of: language)
        let samples = try #require(PluralRules.samples[language])
        let locale = Locale(identifier: language)
        for (key, entry) in catalog.strings {
            let localization = try #require(entry.localizations[language], "\(key)")
            guard localization.isPlural else { continue }
            let format = bundle.localizedString(forKey: key, value: "missing", table: nil)
            for (category, sample) in samples {
                guard let sample else { continue }
                let text = try #require(localization.texts[category], "\(key), \(category)")
                let expected = String(format: text, locale: locale, sample)
                let found = String(format: format, locale: locale, sample)
                #expect(found == expected, "\(key), \(category), \(sample)")
            }
        }
    }
}
#endif
