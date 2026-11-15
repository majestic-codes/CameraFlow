//
//  ExposureStepTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The exposure bias as VoiceOver steps it, on the focus reticle's sun and on the ruler of the Exposure sub-panel.
@MainActor
@Suite("Exposure steps of VoiceOver", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ExposureStepTests {

    @Test("A step moves an adjustable bias by a tick of the ruler and sends it to the camera")
    func adjustable() async {
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service)
        await model.start()
        model.settings.stepExposureBias(by: SubPanelRulerScale.tickBias)
        expectClose(model.settings.exposureBias, 1.0 / 3, tolerance: 0.0001)
        #expect(service.calls.last == .exposureBias(model.settings.exposureBias))
        model.settings.stepExposureBias(by: -SubPanelRulerScale.tickBias)
        model.settings.stepExposureBias(by: -SubPanelRulerScale.tickBias)
        expectClose(model.settings.exposureBias, -1.0 / 3, tolerance: 0.0001)
    }

    @Test("A bias the app fixed stays as it is, and the camera hears of no change")
    func fixed() async {
        var state = CameraFlowInitialState()
        state.exposureBias = .fixed(0.5)
        let service = RecordingCameraService()
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        let callsBefore = service.calls
        model.settings.stepExposureBias(by: SubPanelRulerScale.tickBias)
        model.settings.stepExposureBias(by: -SubPanelRulerScale.tickBias)
        #expect(model.settings.exposureBias == 0.5)
        #expect(service.calls == callsBefore)
    }

    @Test("A step stops at the end of the range the camera accepts")
    func clamped() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        let upper = model.settings.availableExposureBiasRange.upperBound
        model.settings.setExposureBias(upper)
        model.settings.stepExposureBias(by: SubPanelRulerScale.tickBias)
        #expect(model.settings.exposureBias == upper)
    }
}
