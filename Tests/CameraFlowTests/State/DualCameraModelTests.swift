//
//  DualCameraModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Dual camera: the front camera's circle", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraModelTests {
    let service = RecordingCameraService()

    /// A model that offers the circle, opens with a state that keeps every setting the pair offers, and has laid
    /// the circle out.
    private func makeModel(
        initialState: CameraFlowInitialState = DualCameraFixture.keptState,
        isDualCameraOffered: Bool = true,
        onCapture: @escaping (CameraCapture) -> Void = { _ in }
    ) -> PhotoCameraModel {
        let model = makeCaptureModel(
            service: service,
            initialState: initialState,
            isDualCameraOffered: isDualCameraOffered,
            onCapture: onCapture
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    @Test(
        "The circle is offered only where the flow offers it and the device runs two cameras",
        arguments: [(true, true, true), (true, false, false), (false, true, false), (false, false, false)]
    )
    func availability(isOffered: Bool, isSupported: Bool, isAvailable: Bool) async {
        let service = RecordingCameraService(isDualCameraSupported: isSupported)
        let model = makeCaptureModel(service: service, isDualCameraOffered: isOffered)
        await model.start()
        #expect(model.dualCamera.isAvailable == isAvailable)
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn == isAvailable)
    }

    @Test("Turning the circle on starts the pair, and turning it off the back camera alone")
    func toggle() async {
        let model = makeModel()
        await model.start()
        let started = service.calls.count
        await model.toggleDualCamera()
        #expect(service.calls(after: started) == [.startDualCamera(main: .back), .exposureBias(0)])
        #expect(model.dualCamera.isOn)
        #expect(model.session.photoCapabilities == SimulatedCameraService.iPhoneDualPhotoCapabilities)
        #expect(model.notices.dualCameraNotice == nil)
        let turnedOn = service.calls.count
        await model.toggleDualCamera()
        #expect(service.calls(after: turnedOn) == [.start(.back), .exposureBias(0)])
        #expect(model.dualCamera.isOn == false)
        #expect(model.session.photoCapabilities == SimulatedCameraService.iPhoneBackPhotoCapabilities)
    }

    @Test("Turning the circle on over the front camera keeps it in the viewfinder, and off leaves it alone")
    func toggleFromFront() async {
        let model = makeModel()
        await model.start()
        await model.flipCamera()
        let flipped = service.calls.count
        await model.toggleDualCamera()
        #expect(service.calls(after: flipped) == [.startDualCamera(main: .front), .exposureBias(0)])
        #expect(model.session.position == .front)
        #expect(model.dualCamera.isOn)
        await model.toggleDualCamera()
        #expect(model.session.position == .front)
        #expect(model.dualCamera.isOn == false)
    }

    @Test("A flip with the circle on swaps the cameras, and a second flip swaps them back")
    func swap() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        let turnedOn = service.calls.count
        await model.flipCamera()
        #expect(service.calls(after: turnedOn) == [.startDualCamera(main: .front), .exposureBias(0)])
        #expect(model.dualCamera.isOn)
        #expect(model.session.position == .front)
        #expect(model.session.photoCapabilities == SimulatedCameraService.iPhoneFrontPhotoCapabilities)
        #expect(model.zoom.lenses.map(\.factor) == [1])
        #expect(model.notices.dualCameraNotice == nil)
        let swapped = service.calls.count
        await model.flipCamera()
        #expect(service.calls(after: swapped) == [.startDualCamera(main: .back), .exposureBias(0)])
        #expect(model.session.position == .back)
        #expect(model.session.photoCapabilities == SimulatedCameraService.iPhoneDualPhotoCapabilities)
    }

    @Test("The screen opens with the circle on where the state asks for it")
    func opensWithCircle() async {
        var state = DualCameraFixture.keptState
        state.isDualCameraEnabled.value = true
        let model = makeModel(initialState: state)
        await model.start()
        #expect(service.calls == [.startDualCamera(main: .back), .exposureBias(0)])
        #expect(model.dualCamera.isOn)
    }

    @Test("The screen opens swapped, with the front camera in the viewfinder, where the state asks for it")
    func opensSwapped() async {
        var state = DualCameraFixture.keptState
        state.isDualCameraEnabled.value = true
        state.isDualCameraSwapped = true
        let model = makeModel(initialState: state)
        await model.start()
        #expect(service.calls == [.startDualCamera(main: .front), .exposureBias(0)])
        #expect(model.session.position == .front)
        #expect(model.dualCamera.circlePosition == .back)
    }

    @Test("A stopped camera with the circle on resumes as the pair, the same camera in the viewfinder")
    func resume() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        await model.flipCamera()
        model.stop()
        let stopped = service.calls.count
        await model.resume()
        #expect(service.calls(after: stopped) == [.startDualCamera(main: .front), .exposureBias(0), .setZoom(1)])
        #expect(model.dualCamera.isOn)
        #expect(model.session.position == .front)
    }

    @Test("A pair the hardware cannot run leaves the camera that ran, says so and stops offering the circle")
    func unavailable() async {
        service.dualStartError = .dualCameraUnavailable("No pair of formats fits")
        let model = makeModel()
        await model.start()
        await model.flipCamera()
        let flipped = service.calls.count
        await model.toggleDualCamera()
        #expect(service.calls(after: flipped) == [.startDualCamera(main: .front), .start(.front), .exposureBias(0)])
        #expect(model.dualCamera.isOn == false)
        #expect(model.dualCamera.isAvailable == false)
        #expect(model.session.position == .front)
        #expect(model.notices.dualCameraNotice == .unavailable)
        #expect(model.session.failure == nil)
    }

    @Test("A pair that fails for another reason stays offered for the next try")
    func failedStart() async {
        service.dualStartError = .cannotUseCamera("The camera is in use")
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn == false)
        #expect(model.dualCamera.isAvailable)
        #expect(model.notices.dualCameraNotice == .unavailable)
    }

    @Test("Critical system pressure turns the circle off with a notice, and the viewfinder's camera goes on alone")
    func pressure() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        await model.flipCamera()
        let turnedOn = service.calls.count
        await service.simulate(.dualCameraPressureCritical)
        await settle { model.dualCamera.isOn == false }
        #expect(service.calls(after: turnedOn) == [.start(.front), .exposureBias(0)])
        #expect(model.notices.dualCameraNotice == .turnedOffUnderPressure)
    }

    @Test("A switch under way takes no other toggle or flip")
    func switching() async {
        let model = makeModel()
        await model.start()
        service.holdsCalls = true
        async let toggled: Void = model.toggleDualCamera()
        await settle { service.heldCallCount > 0 }
        #expect(model.dualCamera.isToggleEnabled == false)
        await model.toggleDualCamera()
        await model.flipCamera()
        service.holdsCalls = false
        service.releaseHeldCalls()
        await toggled
        #expect(service.calls.filter { $0 == .startDualCamera(main: .back) }.count == 1)
        #expect(service.calls.contains(.startDualCamera(main: .front)) == false)
        #expect(model.dualCamera.isToggleEnabled)
    }

    @Test(
        "The panel has the circle's tile where the flow offers it and the device runs two cameras",
        arguments: [(true, true, true), (true, false, false), (false, true, false)]
    )
    func tile(isOffered: Bool, isSupported: Bool, hasTile: Bool) {
        let service = RecordingCameraService(isDualCameraSupported: isSupported)
        let model = makeCaptureModel(service: service, isDualCameraOffered: isOffered)
        let stock: [CameraSetting] = [.flash, .live, .aspect, .timer, .exposure, .format]
        let expected = stock + (hasTile ? [.dualCamera] : [])
        #expect(model.settings.offeredSettings == expected)
        #expect(model.panel.settings == expected)
    }

    @Test("The tile's value follows the circle")
    func tileValue() async {
        let model = makeModel()
        await model.start()
        #expect(CameraSettingText(.system).value(of: .dualCamera, in: model.settings) == "Off")
        await model.toggleDualCamera()
        #expect(CameraSettingText(.system).value(of: .dualCamera, in: model.settings) == "On")
    }

    @Test("Every switch asks the camera for one start, each the right kind, in the order of the taps")
    func transitions() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        await model.toggleDualCamera()
        await model.toggleDualCamera()
        await model.flipCamera()
        await model.flipCamera()
        model.stop()
        await model.resume()
        await model.flipCamera()
        await model.toggleDualCamera()
        await model.flipCamera()
        let starts = service.calls.filter { call in
            switch call {
            case .start, .startDualCamera, .stop: true
            default: false
            }
        }
        #expect(starts == [
            .start(.back),
            .startDualCamera(main: .back),
            .start(.back),
            .startDualCamera(main: .back),
            .startDualCamera(main: .front),
            .startDualCamera(main: .back),
            .stop,
            .startDualCamera(main: .back),
            .startDualCamera(main: .front),
            .start(.front),
            .start(.back)
        ])
    }
}
