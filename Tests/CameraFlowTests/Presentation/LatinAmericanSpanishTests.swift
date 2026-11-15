//
//  LatinAmericanSpanishTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Latin American Spanish")
struct LatinAmericanSpanishTests {

    private static func localization(_ identifier: String) -> FlowLocalization {
        FlowLocalization(.specific(Locale.Language(identifier: identifier)))
    }

    @Test(
        "Spanish of the Americas gets the Latin American texts, the Spanish of Spain the texts of Spain",
        arguments: [
            ("es-MX", "es-419"), ("es-US", "es-419"), ("es-AR", "es-419"), ("es-CO", "es-419"), ("es-419", "es-419"),
            ("es", "es"), ("es-ES", "es")
        ]
    )
    func regions(language: String, localizationName: String) {
        #expect(Self.localization(language).localizationName == localizationName)
    }

    @Test("The Settings app is Configuración in Latin America and Ajustes in Spain")
    func settingsApp() {
        let mexico = CameraNoticeText(Self.localization("es-MX"))
        let denied = "El acceso a la cámara está denegado en Configuración"
        #expect(mexico.openSettings == "Abrir Configuración")
        #expect(mexico.message(for: CameraFailure.accessDenied) == denied)
        #expect(CameraNoticeText(Self.localization("es-ES")).openSettings == "Abrir Ajustes")
    }

    @Test("The camera's controls are the stock camera's Latin American texts")
    func stockTexts() {
        let mexico = Self.localization("es-MX")
        #expect(CameraControlText(mexico).shutter(isCountingDown: false) == "Tomar foto")
        #expect(CameraSettingText(mexico).switchState(isOn: true) == "Sí")
        #expect(CameraSettingText(mexico).switchState(isOn: false) == "No")
        #expect(ZoomFactorTitle.current(2, localization: mexico) == "2×")
        #expect(ZoomFactorTitle.current(2, localization: Self.localization("es-ES")) == "x2")
    }

    @Test("The flow's own texts take the Latin American words of the system")
    func flowTexts() {
        let mexico = Self.localization("es-MX")
        #expect(FlowText(mexico).accept == "Listo")
        #expect(ReviewText(mexico).addFromLibrary == "Agregar desde la fototeca")
        #expect(ReviewText(mexico).markup == "Marcado")
    }

    @Test(
        "A count picks the Spanish plural form",
        arguments: [(1, "El conjunto tiene 1 foto."), (2, "El conjunto tiene 2 fotos.")]
    )
    func pluralForms(count: Int, message: String) {
        let confirmation = ExitConfirmation(photoCount: count, hasCameraPhotos: false)
        #expect(FlowText(Self.localization("es-MX")).exitMessage(for: confirmation) == message)
    }
}
