//
//  FlowTextLocaleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The locale of the flow's texts")
struct FlowTextLocaleTests {

    private static func localization(_ identifier: String) -> FlowLocalization {
        FlowLocalization(.specific(Locale.Language(identifier: identifier)))
    }

    @Test(
        "English texts of a language the package lacks take the English plural forms, not the ones of the language",
        arguments: [
            ("ms", 1, "The set has 1 photo."), ("ms", 2, "The set has 2 photos."),
            ("sl", 101, "The set has 101 photos."), ("sl", 102, "The set has 102 photos."),
            ("is", 21, "The set has 21 photos.")
        ]
    )
    func englishPluralForms(language: String, count: Int, message: String) {
        let confirmation = ExitConfirmation(photoCount: count, hasCameraPhotos: false)
        #expect(Self.localization(language).localizationName == "en")
        #expect(FlowText(Self.localization(language)).exitMessage(for: confirmation) == message)
    }

    @Test("A notice in English counts its photos in English in a language the package lacks")
    func englishNotices() {
        let text = FlowText(Self.localization("ms"))
        #expect(text.message(for: PhotoSetNotice.importFailed(count: 1)) == "1 photo could not be loaded")
        #expect(text.message(for: PhotoSetNotice.importFailed(count: 2)) == "2 photos could not be loaded")
    }

    @Test("English texts of a language the package lacks take the English capitals, without a dotted İ")
    func englishCapitals() {
        let azerbaijani = Self.localization("az")
        #expect(CameraSettingText(azerbaijani).tileLabel(of: .live) == "LIVE")
        #expect(CameraSettingText(azerbaijani).title(of: .timer) == "TIMER")
        #expect(FlowText(azerbaijani).modeLabel(.review) == "REVIEW")
    }

    @Test(
        "The numbers of a language the package lacks keep its digits and the separators of its region",
        arguments: [("sl", "2,5 times"), ("ms", "2.5 times"), ("fa-IR", "۲٫۵ times")]
    )
    func numbersOfTheLanguage(language: String, zoom: String) {
        #expect(CameraControlText(Self.localization(language)).zoomValue(2.5) == zoom)
    }

    @Test("A text locale is the language of the texts with the region and the digits of the formats")
    func textLocale() {
        let persian = FlowLocalization.textLocale(of: "en", formats: Locale(identifier: "fa_IR"))
        #expect(persian.language.languageCode == .english)
        #expect(persian.region == .iran)
        #expect(persian.numberingSystem == Locale(identifier: "fa_IR").numberingSystem)
    }

    @Test(
        "The formats stay as they are where they are in the language of the texts",
        arguments: [("es", "es_MX"), ("pt-PT", "pt_PT"), ("zh-Hant", "zh_Hant_HK"), ("en", "en_UA")]
    )
    func formatsInTheLanguageOfTheTexts(localizationName: String, formats: String) {
        let locale = Locale(identifier: formats)
        #expect(FlowLocalization.textLocale(of: localizationName, formats: locale) == locale)
    }

    /// An app that allows mixed localisations gets the package's texts in the device's language, while its own
    /// locale keeps the app's language with the device's region, such as English in Ukraine.
    @Test("Texts the system resolves in another language than the app's locale take the plural forms of the texts")
    func systemTextsInAnotherLanguage() throws {
        let locale = FlowLocalization.textLocale(of: "uk", formats: Locale(identifier: "en_UA"))
        #expect(locale.language.languageCode == .ukrainian)
        #expect(locale.region == .ukraine)
        let path = try #require(Bundle.module.path(forResource: "uk", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: "camera.option.seconds", value: nil, table: nil)
        #expect(String(format: format, locale: locale, 10) == "10 секунд")
        #expect(String(format: format, locale: locale, 3) == "3 секунди")
    }
}
