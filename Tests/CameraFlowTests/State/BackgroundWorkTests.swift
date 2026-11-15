//
//  BackgroundWorkTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The work the app is kept running for in the background, so going home at once loses neither a photo whose
/// shutter fired nor a set the user accepted.
@MainActor
@Suite("Work kept running in the background", .temporaryDirectory, .timeLimit(.minutes(1)))
struct BackgroundWorkTests {
    let service = RecordingCameraService()
    let work = RecordingBackgroundWork()
    let files = CaptureTestSupport.makeFileStore()

    @Test("A photo is taken and handed over inside background time")
    func shot() async throws {
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, files: files, backgroundWork: work) { captures.append($0) }
        await model.start()
        service.holdsCalls = true
        let capturing = Task { await model.capture() }
        await settle { service.heldCallCount == 1 }
        #expect(work.runningCount == 1)
        #expect(work.names == ["CameraFlow photo"])
        service.releaseHeldCalls()
        await capturing.value
        #expect(work.runningCount == 0)
        #expect(captures.count == 1)
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("A refused shot asks for no background time")
    func refusedShot() async {
        let model = makeCaptureModel(
            service: service,
            files: files,
            storage: FakeStorageSpace(room: .bytes(0)),
            backgroundWork: work
        )
        await model.start()
        await model.capture()
        #expect(work.names.isEmpty)
    }

    @Test(
        "The hand-over runs inside background time, and so does a save right after a shot",
        arguments: [CameraFlowPhotoLibrarySaving.Moment.whenSetAccepted, .afterEachPhoto]
    )
    func saves(moment: CameraFlowPhotoLibrarySaving.Moment) async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorization: .authorized, gate: gate)
        let saving = CaptureTestSupport.makeLibrarySaving(moment: moment, writer: writer)
        var handedOver: [[CameraFlowPhoto]] = []
        let photoSet = PhotoSetModel(
            limit: .unlimited,
            fileStore: files,
            librarySaving: saving,
            renderer: RecordingMarkupRenderer(),
            backgroundWork: work
        ) { handedOver.append($0) }
        let camera = makeCaptureModel(
            service: service,
            librarySaving: saving,
            files: files,
            admission: photoSet,
            backgroundWork: work,
            onCapture: photoSet.add
        )
        await camera.start()
        await camera.capture()
        let handingOver = Task { await photoSet.handOver() }
        await gate.arrival()
        let expected = moment == .whenSetAccepted ? "CameraFlow hand-over" : "CameraFlow library save"
        #expect(work.names.contains(expected))
        #expect(work.runningCount >= 1)
        await gate.open()
        await handingOver.value
        #expect(work.runningCount == 0)
        let photos = try #require(handedOver.first)
        #expect(photos.map(\.photoLibrarySave) == [.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1"))])
        try FlowTestSupport.discardFiles(of: photos)
    }
}
