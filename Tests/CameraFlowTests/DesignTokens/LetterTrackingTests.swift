//
//  LetterTrackingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Letter tracking by language")
struct LetterTrackingTests {

    @Test(
        "A language the stock camera sets solid gets no tracking",
        arguments: ["ar", "ar-SA", "hi", "hi-IN", "th", "th-TH", "bn", "ml", "pa", "ta"]
    )
    func untrackedLanguages(language: String) {
        let tracking = LetterTracking(language: language)
        #expect(tracking.isTracked == false)
        #expect(tracking.amount(0.52) == 0)
    }

    @Test(
        "Every other language keeps the stock tracking, a language of another script of India too",
        arguments: ["en", "uk", "de", "he", "mr", "ja", "ko", "zh-Hans", "zh-Hant", "pt-BR", "el", "tr", "vi"]
    )
    func trackedLanguages(language: String) {
        let tracking = LetterTracking(language: language)
        #expect(tracking.isTracked)
        #expect(tracking.amount(0.52) == 0.52)
    }

    @Test("A language that names no known language keeps the stock tracking")
    func unknownLanguage() {
        #expect(LetterTracking(language: "").amount(0.5) == 0.5)
        #expect(LetterTracking(language: "zxx").amount(0.5) == 0.5)
    }

    @Test("The system language takes the tracking of the localisation the package bundle resolves")
    func systemLanguage() throws {
        let language = try #require(Bundle.module.preferredLocalizations.first)
        #expect(LetterTracking(FlowLocalization.system) == LetterTracking(language: language))
    }

    @Test("A language set for the flow takes its own tracking, whatever the device's language is")
    func specificLanguage() {
        let thai = FlowLocalization(.specific(Locale.Language(identifier: "th")))
        let ukrainian = FlowLocalization(.specific(Locale.Language(identifier: "uk")))
        #expect(LetterTracking(thai).isTracked == false)
        #expect(LetterTracking(ukrainian).isTracked)
    }

    #if os(macOS)
    @Test("Arabic, Hindi and Thai are the languages of the package set without tracking")
    func catalogLanguages() {
        let untracked = StringCatalog.languages.filter { LetterTracking(language: $0).isTracked == false }
        #expect(untracked == ["ar", "hi", "th"])
    }

    @Test("Capitals leave an Arabic label as it is written")
    func arabicHasNoCapitals() throws {
        let catalog = try StringCatalog.checkout()
        let locale = Locale(identifier: "ar")
        let settings = catalog.strings.keys.filter { $0.hasPrefix("camera.setting.") }
        #expect(settings.count == 9)
        for key in settings + ["flow.mode.shooting", "flow.mode.review"] {
            let text = try catalog.text(key, in: "ar")
            #expect(text.uppercased(with: locale) == text, "\(key)")
        }
    }
    #endif
}
