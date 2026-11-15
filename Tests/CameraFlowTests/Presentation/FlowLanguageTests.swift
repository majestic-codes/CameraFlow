//
//  FlowLanguageTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The language of the flow's texts")
struct FlowLanguageTests {

    private static func localization(_ identifier: String) -> FlowLocalization {
        FlowLocalization(.specific(Locale.Language(identifier: identifier)))
    }

    @Test("A flow speaks the language the system resolves unless the app names one")
    func systemByDefault() {
        let configuration = CameraFlowConfiguration()
        let localization = FlowLocalization(configuration.language)
        #expect(configuration.language == .system)
        #expect(localization.isSystem)
        #expect(localization.bundle == Bundle.module)
        #expect(localization.localizationName == Bundle.module.preferredLocalizations.first)
        let textLanguage = Locale.Language(identifier: localization.localizationName)
        #expect(localization.locale.language.languageCode == textLanguage.languageCode)
        #expect(localization.locale.region == Locale.current.region)
    }

    @Test(
        "VoiceOver is told the language of the texts where the app names one, and nothing where the system picks it",
        arguments: [("uk-UA", "uk"), ("pt", "pt-BR"), ("zh-TW", "zh-Hant"), ("ar", "ar"), ("sw", "en")]
    )
    func spokenLanguage(language: String, spoken: String) {
        #expect(Self.localization(language).spokenLanguage == spoken)
        #expect(FlowLocalization.system.spokenLanguage == nil)
    }

    @Test("The system language gives the texts the package bundle resolves, as before the setting")
    func systemTexts() {
        let resolved = String(localized: "flow.control.accept", defaultValue: "Done", bundle: .module)
        #expect(FlowText(.system).accept == resolved)
    }

    @Test(
        "A language the app names gives the flow's texts in it, whatever the device's language is",
        arguments: [("uk", "Готово"), ("ar", "تم"), ("en", "Done")]
    )
    func specificTexts(language: String, accept: String) {
        #expect(FlowText(Self.localization(language)).accept == accept)
    }

    @Test(
        "A language is matched to the closest one the package has",
        arguments: [
            ("uk-UA", "uk"), ("pt", "pt-BR"), ("pt-PT", "pt-PT"), ("es-MX", "es-419"), ("es-ES", "es"),
            ("zh-TW", "zh-Hant"), ("no", "nb")
        ]
    )
    func closestLanguage(language: String, localizationName: String) {
        #expect(Self.localization(language).localizationName == localizationName)
    }

    @Test("A language the package lacks gives English texts and its own formats for numbers")
    func unsupportedLanguage() {
        let persian = Self.localization("fa-IR")
        #expect(persian.localizationName == "en")
        #expect(FlowText(persian).accept == "Done")
        #expect(CameraSettingText(persian).megapixelCount(12) == "۱۲")
    }

    @Test("The supported languages are the 37 of the catalog")
    func supportedLanguages() {
        let identifiers = Set(CameraFlowLanguage.supportedLanguages.map(\.minimalIdentifier))
        #expect(CameraFlowLanguage.supportedLanguages.count == 37)
        #expect(identifiers.contains("uk"))
        #expect(CameraFlowLanguage.supportedLanguages.contains { $0.script?.identifier == "Hant" })
    }

    @Test(
        "A count picks the plural form of the flow's language",
        arguments: [(1, "Zestaw zawiera 1 zdjęcie."), (3, "Zestaw zawiera 3 zdjęcia."), (5, "Zestaw zawiera 5 zdjęć.")]
    )
    func pluralForms(count: Int, message: String) {
        let confirmation = ExitConfirmation(photoCount: count, hasCameraPhotos: false)
        #expect(FlowText(Self.localization("pl")).exitMessage(for: confirmation) == message)
    }

    @Test("Accessibility reads the zoom in the flow's language, with its decimal separator")
    func accessibilityNumbers() {
        #expect(CameraControlText(Self.localization("uk")).lens(0.5) == "Масштаб 0,5×")
        #expect(CameraControlText(Self.localization("en")).zoomValue(2.5) == "2.5 times")
    }

    @Test("Capitals follow the flow's language")
    func capitals() {
        #expect(FlowText(Self.localization("uk")).modeLabel(.shooting) == "ЗЙОМКА")
        #expect(FlowText(Self.localization("tr")).modeLabel(.shooting) == "KAMERA")
        #expect(CameraSettingText(Self.localization("tr")).qualityTitle == "KALİTE")
        #expect(CameraSettingText(Self.localization("en")).qualityTitle == "QUALITY")
        #expect(CameraSettingText(Self.localization("tr")).title(of: .format) == "BİÇİM")
    }

    @Test("The self-timer counts down in the digits of the flow's language", arguments: [
        ("en", "3"), ("uk", "3"), ("ar", "٣"), ("fa-IR", "۳")
    ])
    func countdownDigits(language: String, digits: String) {
        #expect(CameraSettingText(Self.localization(language)).countdown(3) == digits)
    }

    @Test("The sub-panel of the circle is titled with the name accessibility reads, in every language")
    func dualCameraTitle() {
        let polish = CameraSettingText(Self.localization("pl"))
        #expect(polish.name(of: .dualCamera) == "Oba aparaty")
        #expect(polish.title(of: .dualCamera) == "OBA APARATY")
    }

    @Test("A notice of the camera comes in the flow's language")
    func notices() {
        let text = CameraNoticeText(Self.localization("de")).message(for: DualCameraNotice.unavailable)
        let english = CameraNoticeText(Self.localization("en")).message(for: DualCameraNotice.unavailable)
        #expect(text != english)
        #expect(english == "Front camera unavailable")
    }

    @Test("The exposure is written with the flow's decimal separator")
    func exposure() {
        #expect(CameraSettingText(Self.localization("de")).signedStops(0.7) == "+0,7")
        #expect(CameraSettingText(Self.localization("en")).signedStops(-1.3) == "-1.3")
    }
}
