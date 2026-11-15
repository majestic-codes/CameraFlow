//
//  FlowOutcomeRelayTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("What the flows of the view controller report to the app", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowOutcomeRelayTests {
    let files = CaptureTestSupport.makeFileStore()

    /// What the app's closures heard.
    @MainActor
    private final class AppClosures {
        var finished: [[CameraFlowPhoto]] = []
        var cancelCount = 0
        var preferences: [CameraFlowPreferences] = []

        func makeRelay(withFinish: Bool = true) -> FlowOutcomeRelay {
            let onFinish: ([CameraFlowPhoto]) -> Void = { self.finished.append($0) }
            let onCancel = { self.cancelCount += 1 }
            let onPreferencesChange: (CameraFlowPreferences) -> Void = { self.preferences.append($0) }
            return FlowOutcomeRelay(
                onPreferencesChange: onPreferencesChange,
                onFinish: withFinish ? onFinish : nil,
                onCancel: onCancel
            )
        }
    }

    /// The app's delegate of a controller, which records what reached it.
    @MainActor
    private final class Delegate {
        var finished: [[CameraFlowPhoto]] = []
        var cancelCount = 0
        var preferences: [CameraFlowPreferences] = []
    }

    /// A controller as the relay sees it: it passes what reaches it to its delegate, which it holds weakly as the view
    /// controller does, and counts the sets that reached nobody.
    @MainActor
    private final class Controller: FlowOutcomeReceiver {
        weak var delegate: Delegate?
        var finishedWithoutReceiverCount = 0

        init(delegate: Delegate?) {
            self.delegate = delegate
        }

        var hasDelegate: Bool {
            delegate != nil
        }

        func flowFinished(with photos: [CameraFlowPhoto]) {
            delegate?.finished.append(photos)
        }

        func flowFinishedWithoutReceiver() {
            finishedWithoutReceiverCount += 1
        }

        func flowCancelled() {
            delegate?.cancelCount += 1
        }

        func preferencesChanged(_ preferences: CameraFlowPreferences) {
            delegate?.preferences.append(preferences)
        }
    }

    /// A photo as a set hands it over, with a file of its own.
    private func makePhoto() throws -> CameraFlowPhoto {
        let capture = try FlowTestSupport.makeCapture(in: files)
        return CameraFlowPhoto(FlowPhoto(capture: capture), markedUpCopy: nil, photoLibrarySave: nil)
    }

    /// A set that reports to the relay as the set of a controller's flow does, with one photo with a drawing, whose
    /// copy the renderer writes at the hand-over.
    private func makeSet(
        reportingTo relay: FlowOutcomeRelay,
        renderer: RecordingMarkupRenderer
    ) throws -> PhotoSetModel {
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: renderer) { relay.finish(with: $0) }
        photoSet.handOverObserver = relay
        let capture = try FlowTestSupport.makeCapture(in: files, withMovie: true)
        photoSet.add(capture)
        photoSet.setDrawing(try FlowTestSupport.makeDrawing(), ofPhoto: capture.id)
        return photoSet
    }

    @Test("Every report reaches the app's closures and the controller, in the order of the flows")
    func everyReport() throws {
        let app = AppClosures()
        let delegate = Delegate()
        let controller = Controller(delegate: delegate)
        let relay = app.makeRelay()
        relay.receiver = controller
        let first = [try makePhoto()]
        let second = [try makePhoto(), try makePhoto()]
        var preferences = CameraFlowPreferences()
        preferences.isLivePhotoEnabled = false

        relay.preferencesChanged(preferences)
        relay.finish(with: first)
        relay.cancel()
        relay.finish(with: second)

        #expect(app.finished.map { $0.map(\.id) } == [first.map(\.id), second.map(\.id)])
        #expect(delegate.finished.map { $0.map(\.id) } == [first.map(\.id), second.map(\.id)])
        #expect(app.cancelCount == 1)
        #expect(delegate.cancelCount == 1)
        #expect(app.preferences == [preferences])
        #expect(delegate.preferences == [preferences])
        try FlowTestSupport.discardFiles(of: first + second)
    }

    @Test("A set handed over after the controller went away still reaches the app's onFinish")
    func controllerGone() throws {
        let app = AppClosures()
        let relay = app.makeRelay()
        let delegate = Delegate()
        var controller: Controller? = Controller(delegate: delegate)
        relay.receiver = controller
        controller = nil
        let photos = [try makePhoto()]

        relay.finish(with: photos)
        relay.cancel()

        #expect(relay.receiver == nil)
        #expect(app.finished.map { $0.map(\.id) } == [photos.map(\.id)])
        #expect(app.cancelCount == 1)
        #expect(delegate.finished.isEmpty)
        try FlowTestSupport.discardFiles(of: photos)
    }

    @Test("A set reaches someone through onFinish, or through the delegate of a controller that exists")
    func deliversSets() {
        let app = AppClosures()
        #expect(app.makeRelay().deliversSets)

        let relay = app.makeRelay(withFinish: false)
        #expect(relay.deliversSets == false)
        let controller = Controller(delegate: nil)
        relay.receiver = controller
        #expect(relay.deliversSets == false)
        let delegate = Delegate()
        controller.delegate = delegate
        #expect(relay.deliversSets)
        #expect(relay.receivesSets)
    }

    @Test("A controller the app released while its set was handed over still tells its delegate, and goes after it")
    func controllerKeptThroughTheHandOver() async throws {
        let gate = CallGate()
        let app = AppClosures()
        let relay = app.makeRelay(withFinish: false)
        let delegate = Delegate()
        var controller: Controller? = Controller(delegate: delegate)
        weak let releasedController = controller
        relay.receiver = controller
        let photoSet = try makeSet(reportingTo: relay, renderer: RecordingMarkupRenderer(gate: gate))
        let handingOver = Task { await photoSet.handOver() }
        await gate.arrival()

        controller = nil
        #expect(releasedController != nil)
        await gate.open()
        await handingOver.value

        let handedOver = try #require(delegate.finished.first)
        #expect(delegate.finished.count == 1)
        #expect(handedOver.flatMap(\.fileURLs).allSatisfy(FlowTestSupport.fileExists))
        #expect(releasedController == nil)
        #expect(relay.receiver == nil)
        try FlowTestSupport.discardFiles(of: handedOver)
    }

    @Test("A hand-over that ends without a set, a copy failed after the presentation ended, lets the controller go too")
    func controllerGoesAfterAFailedHandOver() async throws {
        let gate = CallGate()
        let renderer = RecordingMarkupRenderer(gate: gate)
        await renderer.failCopy(number: 1)
        let relay = AppClosures().makeRelay(withFinish: false)
        let delegate = Delegate()
        var controller: Controller? = Controller(delegate: delegate)
        weak let releasedController = controller
        relay.receiver = controller
        let photoSet = try makeSet(reportingTo: relay, renderer: renderer)
        let photos = photoSet.photos
        let handingOver = Task { await photoSet.handOver() }
        await gate.arrival()

        photoSet.discard()
        controller = nil
        #expect(releasedController != nil)
        await gate.open()
        await handingOver.value

        #expect(delegate.finished.isEmpty)
        #expect(photoSet.hasEnded)
        expectDeleted(photos)
        #expect(releasedController == nil)
    }

    @Test("A set whose delegate went away while it was handed over, without onFinish, is deleted and nothing is left")
    func setOfNobody() async throws {
        let gate = CallGate()
        let app = AppClosures()
        let relay = app.makeRelay(withFinish: false)
        var delegate: Delegate? = Delegate()
        let controller = Controller(delegate: delegate)
        relay.receiver = controller
        let photoSet = try makeSet(reportingTo: relay, renderer: RecordingMarkupRenderer(gate: gate))
        let photos = photoSet.photos
        let handingOver = Task { await photoSet.handOver() }
        await gate.arrival()

        delegate = nil
        await gate.open()
        await handingOver.value

        #expect(photoSet.hasEnded)
        #expect(controller.finishedWithoutReceiverCount == 1)
        #expect(app.finished.isEmpty)
        expectDeleted(photos)
        #expect(FlowTestSupport.fileExists(files.directory) == false)
        #expect(try FlowTestSupport.isEntered(files.directory) == false)
    }

    @Test("The controller stays while any hand-over that began on it runs, and goes once the last has ended")
    func overlappingHandOvers() {
        let relay = AppClosures().makeRelay()
        var controller: Controller? = Controller(delegate: nil)
        weak let releasedController = controller
        relay.receiver = controller
        relay.handOverBegan()
        relay.handOverBegan()
        controller = nil

        relay.handOverEnded()
        #expect(releasedController != nil)
        relay.handOverEnded()
        #expect(releasedController == nil)
    }
}
