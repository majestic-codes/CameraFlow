//
//  CameraFlowLanguage.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The language of the flow's own texts: its controls, notices, alerts, introduction and accessibility labels, and
/// the numbers in them.
///
/// ```swift
/// configuration.language = .specific(Locale.Language(identifier: "uk"))
/// ```
///
/// The flow's texts come in the languages of ``supportedLanguages``, 37 in all. A specific language is matched the way
/// the system matches the languages of a device: to the closest one the package has (`uk-UA` to `uk`, `pt` to `pt-BR`,
/// `es-MX` to `es-419`, `zh-TW` to `zh-Hant`), and to English when there is none. The plural forms and the capitals
/// follow the language of the texts, and the numbers keep the digits and the region of the language as it was passed,
/// so a language without texts of its own gets English texts with its own numbers.
///
/// The system's own screens follow the language of the app and the device, never this setting: the photo picker, the
/// alerts that ask for the camera, the location and the photo library (their texts are the usage descriptions of the
/// app's Info.plist), the markup tools of PencilKit and PaperKit, the exposure and zoom sliders of the Camera Control
/// overlay and the Settings app. The overlay's lens picker is the flow's own and follows this setting.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowLanguage: Sendable, Hashable {
    /// The language the system resolves for the app, from the device's languages and the languages the app declares
    /// (its own localisations, `CFBundleLocalizations` or `CFBundleAllowMixedLocalizations`), and the device's
    /// formats for numbers. A language the package lacks gives the English texts.
    case system
    /// This language for every text of the flow, and its formats for numbers, whatever the device's language is.
    /// VoiceOver speaks the flow's labels in it while the flow is on screen.
    case specific(Locale.Language)

    /// The languages the flow has its texts in, such as `en`, `uk` and `zh-Hans`.
    public static var supportedLanguages: [Locale.Language] {
        Bundle.module.localizations.sorted().map(Locale.Language.init(identifier:))
    }
}

/// Where the flow's texts are looked up and how their numbers are written: one language of the package's catalog
/// and the locale of its texts.
struct FlowLocalization: Sendable, Equatable {
    /// The bundle the texts are looked up in: the package's own for the system language, the bundle of one language
    /// for a specific one.
    let bundle: Bundle
    /// The locale of the texts: their language, for the plural forms and the capitals, with the region and the
    /// digits of the formats the language asks for.
    let locale: Locale
    /// The localisation of the catalog the texts come from, such as "en" or "zh-Hans".
    let localizationName: String
    /// Whether the system picks the language, so the views mirror with the device and not with the texts.
    let isSystem: Bool

    /// The texts in the language the system resolves, with the device's formats.
    static var system: Self {
        let name = Self.firstLocalization(of: Bundle.module.preferredLocalizations)
        let locale = Self.textLocale(of: name, formats: .current)
        return Self(bundle: .module, locale: locale, localizationName: name, isSystem: true)
    }

    /// The texts of a flow configured with a language.
    init(_ language: CameraFlowLanguage) {
        switch language {
        case .system:
            self = .system
        case let .specific(language):
            self.init(specific: language)
        }
    }

    private init(bundle: Bundle, locale: Locale, localizationName: String, isSystem: Bool) {
        self.bundle = bundle
        self.locale = locale
        self.localizationName = localizationName
        self.isSystem = isSystem
    }

    /// The closest localisation of the package to a language, its bundle and the locale of its texts with the
    /// language's formats.
    private init(specific language: Locale.Language) {
        let name = Self.localization(closestTo: language)
        guard
            let path = Bundle.module.path(forResource: name, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            preconditionFailure("CameraFlow: the package bundle has no \(name).lproj for the localisation it lists")
        }
        let formats = Locale(identifier: language.maximalIdentifier)
        let locale = Self.textLocale(of: name, formats: formats)
        self.init(bundle: bundle, locale: locale, localizationName: name, isSystem: false)
    }

    /// The locale of the texts of a localisation: the locale of the formats where it is in the language of the
    /// texts, otherwise the language of the texts with the region and the digits of the formats. Foundation picks
    /// a plural form by the language of the locale, never by the bundle the text comes from.
    static func textLocale(of localizationName: String, formats: Locale) -> Locale {
        let language = Locale.Language(identifier: localizationName)
        guard language.languageCode != formats.language.languageCode else {
            return formats
        }
        var components = Locale.Components(
            languageCode: language.languageCode,
            script: language.script,
            languageRegion: formats.region
        )
        components.numberingSystem = formats.numberingSystem
        return Locale(components: components)
    }

    /// The localisation of the package the system would pick for a user whose only language is this one.
    static func localization(closestTo language: Locale.Language) -> String {
        let preferences = [language.minimalIdentifier, language.maximalIdentifier]
        let matches = Bundle.preferredLocalizations(from: Bundle.module.localizations, forPreferences: preferences)
        return firstLocalization(of: matches)
    }

    /// The first of the localisations Foundation matched. Foundation always matches one while the bundle has any,
    /// and the package bundle has every language of its catalog.
    private static func firstLocalization(of matches: [String]) -> String {
        guard let first = matches.first else {
            preconditionFailure("CameraFlow: the package bundle has no localisation")
        }
        return first
    }

    /// Whether the texts run from right to left, such as Arabic and Hebrew.
    var isRightToLeft: Bool {
        Locale.Language(identifier: localizationName).characterDirection == .rightToLeft
    }

    /// The language VoiceOver speaks the flow's labels in, as a BCP 47 tag: the language of the texts where the app
    /// names one. Nil where the system picks the language, which VoiceOver follows by itself.
    var spokenLanguage: String? {
        isSystem ? nil : localizationName
    }
}
