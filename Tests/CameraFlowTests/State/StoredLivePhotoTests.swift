//
//  StoredLivePhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// Where a stored Live Photo "on" comes from, and what keeps the camera from taking one.
struct StoredLivePhotoCase: Sendable, CustomTestStringConvertible {
    enum Source: Sendable {
        case memory
        case appPreference
    }

    enum Obstacle: Sendable {
        case cameraWithoutLivePhoto
        case sixteenByNine
    }

    let source: Source
    let obstacle: Obstacle

    static let all = [
        Self(source: .memory, obstacle: .cameraWithoutLivePhoto),
        Self(source: .memory, obstacle: .sixteenByNine),
        Self(source: .appPreference, obstacle: .cameraWithoutLivePhoto),
        Self(source: .appPreference, obstacle: .sixteenByNine)
    ]

    /// What an earlier flow left: Live Photo on, in 16:9 where that is the obstacle.
    var stored: CameraFlowPreferences {
        var preferences = CameraFlowPreferences()
        preferences.isLivePhotoEnabled = true
        if obstacle == .sixteenByNine {
            preferences.aspectRatio = .sixteenByNine
        }
        return preferences
    }

    var testDescription: String {
        let origin = source == .memory ? "remembered" : "stored by the app"
        let reason = obstacle == .sixteenByNine ? "16:9" : "a camera without Live Photo"
        return "\(origin), \(reason)"
    }
}

@MainActor
@Suite("A stored Live Photo the camera cannot take", .temporaryDirectory, .timeLimit(.minutes(1)))
struct StoredLivePhotoTests {
    private let store = FakePreferenceStore()
    private let reported = ReportedPreferences()

    private var memory: PreferencesMemory {
        CaptureTestSupport.makeMemory(store: store)
    }

    private func makeService(for storedCase: StoredLivePhotoCase) -> RecordingCameraService {
        switch storedCase.obstacle {
        case .cameraWithoutLivePhoto:
            RecordingCameraService(backPhotoCapabilities: CaptureTestSupport.narrowCapabilities)
        case .sixteenByNine:
            RecordingCameraService()
        }
    }

    /// A flow that offers Live Photo and opens with the stored choices of the case.
    private func makeModel(for storedCase: StoredLivePhotoCase, service: RecordingCameraService) -> PhotoCameraModel {
        var preferences = CameraFlowPreferences()
        switch storedCase.source {
        case .memory: memory.store(storedCase.stored)
        case .appPreference: preferences = storedCase.stored
        }
        let report: (CameraFlowPreferences) -> Void = { [reported] in reported.values.append($0) }
        return makeCaptureModel(
            service: service,
            isLivePhotoOffered: true,
            preferences: preferences,
            memory: memory,
            onPreferencesChange: report
        )
    }

    private func lastCaptureRequest(of service: RecordingCameraService) throws -> PhotoCaptureRequest {
        let requests = service.calls.compactMap { call in
            if case let .capture(request) = call { request } else { nil }
        }
        return try #require(requests.last)
    }

    @Test("It shoots a still, stays chosen, and nothing is reported or stored", arguments: StoredLivePhotoCase.all)
    func shootsStill(storedCase: StoredLivePhotoCase) async throws {
        let service = makeService(for: storedCase)
        let model = makeModel(for: storedCase, service: service)
        let writes = store.writeCount
        await model.start()
        let settings = model.settings
        #expect(settings.isLivePhotoEnabled)
        #expect(settings.isLivePhotoSelectable == false)
        #expect(settings.isLivePhotoInEffect == false)
        await model.capture()
        #expect(model.notices.captureError == nil)
        #expect(try lastCaptureRequest(of: service).isLivePhotoEnabled == false)
        #expect(reported.values.isEmpty)
        #expect(store.writeCount == writes)
        #expect(settings.preferences == storedCase.stored)
    }

    @Test("Another setting the user changes leaves the stored Live Photo on", arguments: StoredLivePhotoCase.all)
    func keptThroughAnotherChange(storedCase: StoredLivePhotoCase) async {
        let model = makeModel(for: storedCase, service: makeService(for: storedCase))
        await model.start()
        model.settings.select(timer: .threeSeconds)
        var expected = storedCase.stored
        expected.timer = .threeSeconds
        #expect(reported.values == [expected])
        var remembered = CameraFlowPreferences()
        remembered.timer = .threeSeconds
        #expect(memory.load() == (storedCase.source == .memory ? expected : remembered))
        #expect(model.settings.isLivePhotoEnabled)
    }

    @Test(
        "Back in 4:3 the stored Live Photo is taken again, and only the aspect ratio is reported",
        arguments: [StoredLivePhotoCase.Source.memory, .appPreference]
    )
    func comesBackInFourByThree(source: StoredLivePhotoCase.Source) async throws {
        let storedCase = StoredLivePhotoCase(source: source, obstacle: .sixteenByNine)
        let service = makeService(for: storedCase)
        let model = makeModel(for: storedCase, service: service)
        await model.start()
        model.settings.select(aspectRatio: .fourByThree)
        #expect(model.settings.isLivePhotoInEffect)
        await model.capture()
        #expect(try lastCaptureRequest(of: service).isLivePhotoEnabled)
        var expected = storedCase.stored
        expected.aspectRatio = .fourByThree
        #expect(reported.values == [expected])
    }
}
