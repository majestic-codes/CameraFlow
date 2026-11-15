//
//  FlowTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite("Flow text and identifiers", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowTextTests {

    @Test(
        "A mode has a name for accessibility and the same name in capitals on the switch",
        arguments: [(CameraFlowMode.shooting, "Camera", "CAMERA"), (.review, "Review", "REVIEW")]
    )
    func modes(mode: CameraFlowMode, name: String, label: String) {
        #expect(FlowText(.system).modeName(mode) == name)
        #expect(FlowText(.system).modeLabel(mode) == label)
    }

    @Test("The exit alert says that camera photos are lost for good")
    func exitMessageWithCameraPhotos() {
        let confirmation = ExitConfirmation(photoCount: 3, hasCameraPhotos: true)
        let message = "The set has 3 photos. The ones taken with the camera will be gone for good."
        #expect(FlowText(.system).exitMessage(for: confirmation) == message)
    }

    @Test("The exit alert only counts the photos of a set without camera photos")
    func exitMessageWithLibraryPhotos() {
        let confirmation = ExitConfirmation(photoCount: 3, hasCameraPhotos: false)
        let message = "The set has 3 photos."
        #expect(FlowText(.system).exitMessage(for: confirmation) == message)
    }

    @Test("The exit alert has a title and its two answers")
    func exitAlert() {
        #expect(FlowText(.system).exitTitle == "Leave without the photos?")
        #expect(FlowText(.system).exitStay == "Stay")
        #expect(FlowText(.system).exitLeave == "Leave")
    }

    @Test(
        "A notice of the set says what the library could not add and why the set was not handed over",
        arguments: [
            (PhotoSetNotice.importFailed(count: 2), "2 photos could not be loaded"),
            (.limitReached(5), "Limit of 5 photos reached"),
            (.copyFailed, "The copy with the drawing could not be saved")
        ]
    )
    func setNotice(notice: PhotoSetNotice, message: String) {
        #expect(FlowText(.system).message(for: notice) == message)
    }

    @Test("The controls of the flow have stable identifiers")
    func identifiers() {
        #expect(FlowIdentifier.exit == "flow.exit")
        #expect(FlowIdentifier.accept == "flow.accept")
        #expect(FlowIdentifier.library == "flow.library")
        #expect(FlowIdentifier.mode(.shooting) == "flow.mode.shooting")
        #expect(FlowIdentifier.mode(.review) == "flow.mode.review")
        #expect(FlowIdentifier.modeBadge == "flow.mode.badge")
        #expect(FlowIdentifier.modeImporting == "flow.mode.importing")
    }

    // MARK: - The notice line

    @Test("The notice line is empty while neither the camera nor the set has something to say")
    func noNotice() async throws {
        let flow = try await FlowHarness().makeStartedFlow(photoCount: 0)
        #expect(FlowText(.system).notice(for: flow) == nil)
    }

    @Test("In the shooting mode the camera speaks before the set, and in the review the drawing mode does")
    func noticeLine() async throws {
        let harness = FlowHarness()
        let flow = try await harness.makeStartedFlow(photoCount: 1)
        await flow.photoSet.importPicks([FakeLibraryPick(data: nil), FakeLibraryPick(data: nil)])
        #expect(FlowText(.system).notice(for: flow) == "2 photos could not be loaded")
        await harness.service.simulate(.interrupted(.cameraInUseByAnotherClient))
        #expect(FlowText(.system).notice(for: flow) == "Camera in use by another app")
        flow.showReview()
        #expect(FlowText(.system).notice(for: flow) == "2 photos could not be loaded")
        harness.canvasOpener.failure = .engineUnavailable(.paperKit)
        await flow.startMarkup()
        #expect(FlowText(.system).notice(for: flow) == "Markup could not be opened")
        flow.photoSet.discard()
    }
}
