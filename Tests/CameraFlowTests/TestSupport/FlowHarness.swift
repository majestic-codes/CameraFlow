//
//  FlowHarness.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The flow as the tests run it: over canvases without a view.
typealias TestFlowModel = CameraFlowModel<FakeMarkupCanvas>

/// A new harness, and a flow of it that saves to a fake library: at the check mark, with a switch the user may
/// move, unless the test says otherwise.
@MainActor
func makeSavingFlow(
    writer: FakePhotoLibraryWriter,
    destination: CameraFlowPhotoLibrarySaving.Destination = .library,
    moment: CameraFlowPhotoLibrarySaving.Moment = .whenSetAccepted,
    isOn: Bool = true,
    isUserAdjustable: Bool = true
) -> (FlowHarness, TestFlowModel) {
    let harness = FlowHarness()
    let saving = CaptureTestSupport.makeLibrarySaving(
        isOn: isOn,
        isUserAdjustable: isUserAdjustable,
        destination: destination,
        moment: moment,
        writer: writer
    )
    return (harness, harness.makeFlow(librarySaving: saving))
}

/// What a flow under test told its app: every set it handed over and how often it was left.
@MainActor
final class FlowOutcome {
    var handedOver: [[CameraFlowPhoto]] = []
    var exitCount = 0
}

/// What a flow under test told its app about the user's choices.
@MainActor
final class ReportedPreferences {
    var values: [CameraFlowPreferences] = []
}

/// Builds flows over a recording camera, a recording renderer and fake canvases, and keeps what they tell their
/// app.
@MainActor
struct FlowHarness {
    let service: RecordingCameraService
    let haptics = RecordingCameraHaptics()
    /// The time of the flows' cameras, which moves only when the test advances it.
    let clock = ManualClock()
    let files = CaptureTestSupport.makeFileStore()
    let renderer: RecordingMarkupRenderer
    let canvasOpener = RecordingCanvasOpener()
    let outcome = FlowOutcome()

    init(
        renderer: RecordingMarkupRenderer = RecordingMarkupRenderer(),
        service: RecordingCameraService = RecordingCameraService()
    ) {
        self.renderer = renderer
        self.service = service
    }

    /// A flow over the harness: with Live Photo adjustable, the files untouched, no circle, no saving, no memory and
    /// no introduction unless the test says otherwise.
    func makeFlow(
        limit: CameraFlowPhotoLimit = .unlimited,
        isLibraryPickerEnabled: Bool = true,
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        isDualCameraOffered: Bool = false,
        output: CameraFlowOutput = CameraFlowOutput(),
        memory: PreferencesMemory? = nil,
        librarySaving: PhotoLibrarySavingModel? = nil,
        onboarding: OnboardingModel? = nil,
        attitudeSensor: ManualAttitudeSensor = ManualAttitudeSensor(),
        completion: CameraFlowCompletion = .userConfirms,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil
    ) -> TestFlowModel {
        let photoSet = PhotoSetModel(
            limit: limit,
            fileStore: files,
            output: output,
            librarySaving: librarySaving,
            renderer: renderer
        ) { [outcome] in
            outcome.handedOver.append($0)
        }
        let camera = makeCaptureModel(
            service: service,
            haptics: haptics,
            attitudeSensor: attitudeSensor,
            initialState: initialState,
            isDualCameraOffered: isDualCameraOffered,
            output: output,
            memory: memory,
            librarySaving: librarySaving,
            onboarding: onboarding,
            clock: clock,
            files: files,
            admission: photoSet,
            onCapture: photoSet.add,
            onPreferencesChange: onPreferencesChange
        )
        return CameraFlowModel(
            camera: camera,
            photoSet: photoSet,
            renderer: renderer,
            openCanvas: canvasOpener.open,
            isLibraryPickerEnabled: isLibraryPickerEnabled,
            completion: completion,
            haptics: haptics
        ) { [outcome] in
            outcome.exitCount += 1
        }
    }

    /// A flow whose camera runs and has taken photos, every one of them in the set.
    func makeStartedFlow(photoCount: Int, limit: CameraFlowPhotoLimit = .unlimited) async throws -> TestFlowModel {
        let flow = makeFlow(limit: limit)
        await flow.camera.start()
        for _ in 0..<photoCount {
            await flow.camera.capture()
        }
        let count = flow.photoSet.count
        try #require(count == photoCount, "The set holds \(count) of the \(photoCount) photos the camera took")
        return flow
    }

    /// A flow with photos from the camera, where the photos at `drawnIndices` have a drawing told by its index.
    func makeStartedFlow(photoCount: Int, drawnIndices: [Int]) async throws -> TestFlowModel {
        let flow = try await makeStartedFlow(photoCount: photoCount)
        for index in drawnIndices {
            let drawing = try FlowTestSupport.makeDrawing("drawing \(index)")
            flow.photoSet.setDrawing(drawing, ofPhoto: flow.photoSet.photos[index].id)
        }
        return flow
    }

    /// A flow with photos from the camera whose review is open, on the last photo.
    func makeReviewedFlow(photoCount: Int) async throws -> TestFlowModel {
        let flow = try await makeStartedFlow(photoCount: photoCount)
        flow.showReview()
        return flow
    }

    /// A flow whose review shows the last of its photos from the camera, with the drawing mode open on it, and the
    /// canvas it opened.
    func makeDrawnFlow(photoCount: Int = 2) async throws -> (flow: TestFlowModel, canvas: FakeMarkupCanvas) {
        let flow = try await makeReviewedFlow(photoCount: photoCount)
        await flow.startMarkup()
        let canvas = try #require(canvasOpener.openings.last?.canvas)
        return (flow, canvas)
    }

    func importLibraryPhoto(into flow: TestFlowModel) async throws {
        let data = try FlowTestSupport.makeJPEG()
        await flow.photoSet.importPicks([FakeLibraryPick(data: data)])
    }
}
