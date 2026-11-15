//
//  ZoomDialPanelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The zoom dial and the control panel", .temporaryDirectory, .timeLimit(.minutes(1)))
struct ZoomDialPanelTests {

    @Test("The dial and a sub-panel stay open together: neither closes the other")
    func dialWithSubPanel() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        model.panel.showTiles()
        model.panel.showSubPanel(.format)
        model.zoom.openDial()
        #expect(model.panel.presentation == .subPanel(.format))
        model.panel.showTiles()
        model.panel.showSubPanel(.aspect)
        #expect(model.zoom.isDialOpen)
        #expect(model.panel.presentation == .subPanel(.aspect))
    }
}
