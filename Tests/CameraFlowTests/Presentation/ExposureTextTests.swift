//
//  ExposureTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The exposure bias as the screen writes it", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ExposureTextTests {
    private let service = RecordingCameraService()

    private func makeStartedModel() async -> PhotoCameraModel {
        let model = makeCaptureModel(service: service)
        await model.start()
        return model
    }

    @Test(
        "A bias is written to a tenth of a stop, and one that rounds to nothing as no bias, never as minus zero",
        arguments: [(-0.033, "0.0", "0.0"), (0.04, "0.0", "0.0"), (-0.06, "-0.1", "-0.1"), (0.26, "0.3", "+0.3")]
    )
    func written(bias: Double, value: String, signed: String) async {
        let model = await makeStartedModel()
        let english = FlowLocalization(.specific(Locale.Language(identifier: "en")))
        model.settings.setExposureBias(bias)
        #expect(model.settings.exposureBias == bias)
        #expect(CameraSettingText(english).value(of: .exposure, in: model.settings) == value)
        #expect(CameraSettingText(english).signedStops(bias) == signed)
    }

    @Test("A drag that ends a hair off zero leaves no indicator in the top bar, and the camera keeps its bias")
    func hairOffZero() async {
        let model = await makeStartedModel()
        model.settings.setExposureBias(-0.033)
        #expect(model.settings.displayedExposureBias == 0)
        #expect(model.settings.displayedExposureBias.sign == .plus)
        #expect(model.settings.changedSettings.contains(.exposure) == false)
        #expect(service.calls.last == .exposureBias(-0.033))
        model.settings.setExposureBias(-0.05)
        #expect(model.settings.changedSettings.contains(.exposure))
    }

    @Test("In a language whose numbers carry a sign of their own, a bias of nothing has no minus sign either")
    func noMinusZero() {
        for language in ["ar", "he", "uk", "de"] {
            let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
            let text = CameraSettingText(localization).signedStops(-0.02)
            #expect(text.contains("-") == false, "\(language): \(text)")
        }
    }
}
