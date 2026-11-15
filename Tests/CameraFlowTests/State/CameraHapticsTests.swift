//
//  CameraHapticsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Camera haptics", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraHapticsTests {
    let service = RecordingCameraService()
    let haptics = RecordingCameraHaptics()

    func makeStartedModel() async -> PhotoCameraModel {
        let model = makeCaptureModel(service: service, haptics: haptics)
        await model.start()
        return model
    }

    /// Turns the dial in small steps and returns the zoom factors at which it ticked.
    func tickFactors(of model: PhotoCameraModel, from start: CGFloat, to end: CGFloat) -> [CGFloat] {
        var factors: [CGFloat] = []
        let steps = 400
        for step in 1...steps {
            let factor = start * pow(end / start, CGFloat(step) / CGFloat(steps))
            let before = haptics.events.count
            model.zoom.turnDial(to: factor)
            if haptics.events.count > before {
                factors.append(model.zoom.factor)
            }
        }
        return factors
    }

    @Test("The dial ticks on lens 2, on 5, 6 and 7, and on lens 8, and not beyond the last lens")
    func dialTicks() async throws {
        let model = await makeStartedModel()
        model.zoom.openDial()
        let factors = tickFactors(of: model, from: 1, to: 20)
        #expect(haptics.events == Array(repeating: .dialTick, count: 6))
        let tickedFactors: [CGFloat] = [2, 4, 5, 6, 7, 8]
        let nearest = try factors.map { factor in
            try #require(tickedFactors.min { abs($0 - factor) < abs($1 - factor) })
        }
        #expect(nearest == tickedFactors)
    }

    @Test("A closed dial forgets its zone, so reopening it does not tick at once")
    func dialReopens() async {
        let model = await makeStartedModel()
        model.zoom.openDial()
        model.zoom.turnDial(to: 3)
        model.zoom.closeDial()
        model.zoom.setZoom(6.5)
        model.zoom.openDial()
        haptics.removeAll()
        model.zoom.turnDial(to: 6.6)
        #expect(haptics.events.isEmpty)
    }

    @Test("Opening a sub-panel from its tile plays the selection haptic")
    func settingOpened() async {
        let model = await makeStartedModel()
        model.panel.showTiles()
        model.panel.showSubPanel(.timer)
        #expect(haptics.events == [.settingOpened])
    }

    @Test("Choosing a different option plays the selection haptic, choosing the current one does not")
    func optionSelected() async {
        let model = await makeStartedModel()
        model.settings.select(timer: .threeSeconds)
        model.settings.select(timer: .threeSeconds)
        model.settings.select(flashMode: .off)
        #expect(model.settings.timer == .threeSeconds)
        #expect(model.settings.flashMode == .off)
        #expect(haptics.events == [.optionSelected, .optionSelected])
    }

    @Test("Flipping the camera plays the selection haptic")
    func cameraFlipped() async {
        let model = await makeStartedModel()
        await model.flipCamera()
        #expect(haptics.events == [.cameraFlipped])
    }

    @Test("Lens buttons, the top bar, the panel button, focus and the shutter stay silent, as in the stock camera")
    func silentControls() async {
        let model = await makeStartedModel()
        model.zoom.selectLens(at: 2)
        model.settings.cycleFlash()
        model.settings.toggleLivePhoto()
        model.panel.showTiles()
        model.panel.dismiss()
        model.settings.setExposureBias(0.5)
        model.focus.focus(atUnitPoint: CGPoint(x: 0.5, y: 0.5), devicePoint: .zero)
        await model.capture()
        #expect(haptics.events.isEmpty)
    }
}
