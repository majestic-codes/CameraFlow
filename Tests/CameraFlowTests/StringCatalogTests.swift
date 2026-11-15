//
//  StringCatalogTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

/// `Localizable.xcstrings` checked against the sources: the code and the catalog name the same keys, the English
/// text of a key is the default value in the code, and every key has a text in every language of the package.
@Suite("String Catalog")
struct StringCatalogTests {
    /// One `String(localized:defaultValue:bundle:)` call in the sources.
    private struct Lookup {
        let key: String
        let defaultValue: String
        let path: String
    }

    /// The start of any lookup of a localised string, however it goes on.
    private static var lookupStartPattern: Regex<Substring> {
        #/String\(\s*localized:/#
    }

    /// An interpolation of a default value in the code.
    private static var interpolationPattern: Regex<Substring> {
        #/\\\([^)]*\)/#
    }

    /// A format argument of a text in the catalog.
    private static var argumentPattern: Regex<Substring> {
        #/%(?:lld|@)/#
    }

    /// The lookups of the sources, and how many lookups they start in all, however each goes on.
    private struct SourceLookups {
        let lookups: [Lookup]
        let callCount: Int
    }

    private static let sourceLookups = Result {
        let files = try SourceTree.checkout().files
        let lookupStart = lookupStartPattern
        return SourceLookups(
            lookups: files.flatMap(Self.lookups),
            callCount: files.reduce(0) { $0 + $1.text.matches(of: lookupStart).count }
        )
    }

    private let catalog: StringCatalog
    private let lookups: [Lookup]
    private let lookupCallCount: Int

    init() throws {
        let sourceLookups = try Self.sourceLookups.get()
        catalog = try StringCatalog.checkout()
        lookups = sourceLookups.lookups
        lookupCallCount = sourceLookups.callCount
    }

    /// The lookups of a file that name a key, a default value, and the bundle and the locale of the flow's language.
    private static func lookups(in file: SourceTree.File) -> [Lookup] {
        let pattern = #/
        String\( \s* localized: \s* "([^"]+)" , \s*
        defaultValue: \s* "((?:[^"\\]|\\.)*)" , \s*
        bundle: \s* localization\.bundle \s* , \s*
        locale: \s* localization\.locale \s* \)
        /#
        return file.text.matches(of: pattern).map { match in
            Lookup(key: String(match.1), defaultValue: String(match.2), path: file.path)
        }
    }

    @Test("English is the source language")
    func sourceLanguage() {
        #expect(catalog.sourceLanguage == "en")
    }

    @Test("Every lookup names a key, a default value, and the bundle and the locale of the flow's language")
    func lookupShape() {
        #expect(lookups.isEmpty == false)
        #expect(lookups.count == lookupCallCount)
    }

    @Test("The code and the catalog name the same keys")
    func sameKeys() {
        let used = Set(lookups.map(\.key))
        let stored = Set(catalog.strings.keys)
        #expect(used.subtracting(stored).isEmpty, "Keys missing in the catalog: \(used.subtracting(stored).sorted())")
        #expect(stored.subtracting(used).isEmpty, "Keys the code does not use: \(stored.subtracting(used).sorted())")
    }

    @Test("A key is looked up in one place")
    func uniqueLookups() {
        let repeated = Dictionary(grouping: lookups, by: \.key).filter { $0.value.count > 1 }
        #expect(repeated.isEmpty, "Keys looked up more than once: \(repeated.keys.sorted())")
    }

    @Test("The English text of a key is the default value in the code")
    func englishDefaults() {
        let argument = Self.argumentPattern
        let interpolation = Self.interpolationPattern
        for lookup in lookups {
            let english = catalog.strings[lookup.key]?.localizations["en"]?.texts["other"]
            let stored = english?.replacing(argument, with: "%")
            let written = lookup.defaultValue.replacing(interpolation, with: "%")
            #expect(stored == written, "\(lookup.key) in \(lookup.path)")
        }
    }

    @Test("Every key has a text in every language of the package, and in no other")
    func languages() {
        #expect(StringCatalog.languages.count == 37)
        for (key, entry) in catalog.strings {
            let found = Set(entry.localizations.keys)
            let missing = StringCatalog.languages.subtracting(found).sorted()
            let unknown = found.subtracting(StringCatalog.languages).sorted()
            #expect(missing.isEmpty, "\(key) has no \(missing)")
            #expect(unknown.isEmpty, "\(key) has \(unknown), which the package does not ship")
        }
    }

    @Test("The Ukrainian exit message for 1 photo is the one for 21 and 101 too, so it names no single photo")
    func ukrainianExitMessageForCountsEndingInOne() throws {
        let texts = try #require(catalog.strings["flow.exit.message.camera"]?.localizations["uk"]?.texts)
        #expect(texts["one"] == "У наборі %lld фото. Усе, що знято камерою, зникне назавжди.")
    }
}
#endif
