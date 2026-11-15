//
//  CameraBeforeStartTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// What the models say and do while no camera runs yet, and what they take from the camera once it does.
@MainActor
@Suite(
    "The zoom, the settings and the access of a camera before it has started and as it starts",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct CameraBeforeStartTests {
    private let service = RecordingCameraService()
    private let clock = ManualClock()

    private var zoomCalls: [RecordingCameraService.Call] {
        service.calls.filter { call in
            switch call {
            case .setZoom, .rampZoom: true
            default: false
            }
        }
    }

    // MARK: - Zoom

    @Test("Zoom has no lens, no dial label and a scale of one point, and a lens button that is not there does nothing")
    func zoomWithoutCamera() {
        let model = makeCaptureModel(service: service)
        let zoom = model.zoom
        #expect(zoom.lenses.isEmpty)
        #expect(zoom.scale == ZoomScale(range: 1...1))
        #expect(zoom.scale.normalized(1) == 0)
        #expect(zoom.markedFactors.isEmpty)
        #expect(zoom.dialLabelFactors.isEmpty)
        #expect(zoom.dialSnapFactors.isEmpty)
        #expect(zoom.activeLensIndex == nil)
        zoom.selectLens(at: 0)
        #expect(zoom.factor == 1)
        #expect(zoomCalls.isEmpty)
    }

    @Test("The started back camera marks the 28 and 35 mm framings of its main lens, and the front camera none")
    func markedFactors() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        #expect(model.zoom.markedFactors == [1.2, 1.5])
        #expect(model.zoom.dialLabelFactors == [0.5, 1, 2, 4, 8, 40])
        #expect(model.zoom.dialSnapFactors == [1, 2, 4, 8])
        await model.flipCamera()
        #expect(model.zoom.markedFactors.isEmpty)
        #expect(model.zoom.dialLabelFactors == [1, 5])
    }

    @Test("A lens button beyond the row selects nothing")
    func lensOutOfRange() async {
        let model = makeCaptureModel(service: service)
        await model.start()
        model.zoom.selectLens(at: 99)
        model.zoom.selectLens(at: -1)
        #expect(model.zoom.factor == 1)
        #expect(zoomCalls.isEmpty)
    }

    // MARK: - Settings

    @Test("Before the start nothing is encoded as HEVC, Live Photo is not available and no setting was narrowed")
    func settingsWithoutCamera() {
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = CameraFlowSetting(true)
        let model = makeCaptureModel(service: service, initialState: state, isDualCameraOffered: true)
        #expect(model.settings.encodesHEVC == false)
        #expect(model.settings.isLivePhotoAvailable == false)
        #expect(model.settings.isLivePhotoInEffect == false)
        #expect(model.settings.inEffect == nil)
        let before = PhotoSettingsInEffect(
            isLivePhotoOn: true,
            format: .raw,
            resolution: PhotoCaptureResolution(width: 4032, height: 3024),
            flashMode: .auto
        )
        #expect(model.settings.dualCameraNarrowedSetting(comparedTo: before) == nil)
    }

    @Test("After the start the settings follow the camera: HEVC and Live Photo where it has them")
    func settingsWithCamera() async {
        var state = CameraFlowInitialState()
        state.isLivePhotoEnabled = CameraFlowSetting(true)
        let model = makeCaptureModel(service: service, initialState: state)
        await model.start()
        #expect(model.settings.encodesHEVC)
        #expect(model.settings.isLivePhotoAvailable)
        #expect(model.settings.isLivePhotoInEffect)
    }

    // MARK: - Access

    @Test("A flow that goes away while the system asks for the camera starts no camera")
    func cancelledWhileAsking() async {
        service.isAuthorizationDetermined = false
        service.holdsAuthorization = true
        let model = makeCaptureModel(service: service)
        let start = Task { await model.start() }
        await settle { service.authorizationRequestCount == 1 }
        start.cancel()
        service.releaseHeldCalls()
        await start.value
        #expect(service.calls.isEmpty)
        #expect(model.session.capabilities == nil)
        #expect(model.session.failure == nil)
    }

    @Test("A flow that goes away before it asked for the camera asks for nothing")
    func cancelledBeforeAsking() async {
        service.isAuthorizationDetermined = false
        let model = makeCaptureModel(service: service)
        let start = Task { await model.start() }
        start.cancel()
        await start.value
        #expect(service.authorizationRequestCount == 0)
        #expect(service.calls.isEmpty)
    }

    @Test("A flow without the introduction that goes away while the system asks for the location closes its camera")
    func cancelledWhileAskingForLocation() async {
        let location = FakeLocation()
        location.holdsRequest = true
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            onboarding: OnboardingModel(setting: .off, service: service, location: location),
            clock: clock,
            files: CaptureTestSupport.makeFileStore(),
            location: location
        ) { _ in }
        let script = CameraFixtureScript(initialState: CameraFlowInitialState(), clock: clock)
        let running = Task { await CameraScreenLifetime.run(model, script: script) }
        await settle { location.heldRequestCount == 1 }
        running.cancel()
        await running.value
        #expect(service.calls == [.start(.back), .exposureBias(0), .stop])
        #expect(location.followCalls == [true, false])
        #expect(location.heldRequestCount == 0)
        #expect(location.authorization == .notDetermined)
    }
}
