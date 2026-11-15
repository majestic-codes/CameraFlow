//
//  FlowElementRotationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// A phone held in one quarter in the shooting mode and turned to another while the review or the drawing is open.
struct TurnAwayCase: Sendable, CustomTestStringConvertible {
    let shotIn: CameraOrientation
    let turnedTo: CameraOrientation

    static let all = CameraOrientation.allCases.flatMap { shotIn in
        CameraOrientation.allCases.map { turnedTo in
            Self(shotIn: shotIn, turnedTo: turnedTo)
        }
    }

    var testDescription: String {
        "shot in \(shotIn), turned to \(turnedTo)"
    }
}

@MainActor
@Suite("Upright elements across the modes of the flow", .temporaryDirectory, .timeLimit(.minutes(1)))
struct FlowElementRotationTests {
    let harness = FlowHarness()
    let sensor = ManualAttitudeSensor()

    /// A flow whose camera runs with photos taken, held in a quarter.
    private func makeFlow(heldIn orientation: CameraOrientation) async -> TestFlowModel {
        let flow = harness.makeFlow(attitudeSensor: sensor)
        await flow.camera.start()
        await flow.camera.capture()
        await flow.camera.capture()
        sensor.simulate(.upright(in: orientation))
        return flow
    }

    private func expectUpright(_ flow: TestFlowModel, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(flow.elementRotation.orientation == .portrait, sourceLocation: sourceLocation)
        #expect(flow.elementRotation.degrees.remainder(dividingBy: 360) == 0, sourceLocation: sourceLocation)
    }

    // MARK: - Shooting and review

    @Test(
        "The shooting mode turns the elements to the quarter the phone is held in",
        arguments: CameraOrientation.allCases
    )
    func shooting(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        #expect(flow.mode == .shooting)
        #expect(flow.elementRotation == flow.camera.orientation.elementRotation)
        #expect(flow.elementRotation.orientation == orientation)
        flow.photoSet.discard()
    }

    @Test("The review stands upright however the phone was held in shooting", arguments: CameraOrientation.allCases)
    func review(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        flow.showReview()
        #expect(flow.mode == .review)
        expectUpright(flow)
        #expect(flow.camera.orientation.elementRotation.orientation == orientation)
        flow.photoSet.discard()
    }

    @Test("The review turns back by the shortest way", arguments: CameraOrientation.allCases)
    func reviewTurnsBackTheShortestWay(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        let shooting = flow.elementRotation.degrees
        flow.showReview()
        expectClose(flow.elementRotation.degrees, shooting, tolerance: 180)
        flow.photoSet.discard()
    }

    @Test("Back from the review, the shooting mode stands as the phone is held", arguments: CameraOrientation.allCases)
    func backToShooting(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        flow.showReview()
        await flow.showShooting()
        #expect(flow.mode == .shooting)
        #expect(flow.elementRotation.orientation == orientation)
        flow.photoSet.discard()
    }

    // MARK: - Markup

    @Test("The drawing and the review after it stand upright", arguments: CameraOrientation.allCases)
    func markup(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        flow.showReview()
        await flow.startMarkup()
        #expect(flow.markup.isOpen)
        expectUpright(flow)
        flow.markup.cancel()
        #expect(flow.markup.isOpen == false)
        expectUpright(flow)
        await flow.showShooting()
        #expect(flow.elementRotation.orientation == orientation)
        flow.photoSet.discard()
    }

    // MARK: - Turning the phone away from the camera

    @Test("A phone turned in the review leaves it upright, the camera comes back turned", arguments: TurnAwayCase.all)
    func turnedInReview(turnCase: TurnAwayCase) async {
        let flow = await makeFlow(heldIn: turnCase.shotIn)
        flow.showReview()
        sensor.simulate(.upright(in: turnCase.turnedTo))
        expectUpright(flow)
        await flow.showShooting()
        #expect(flow.elementRotation.orientation == turnCase.turnedTo)
        #expect(flow.elementRotation == flow.camera.orientation.elementRotation)
        flow.photoSet.discard()
    }

    @Test(
        "A phone turned in the drawing leaves it upright and the camera comes back turned",
        arguments: TurnAwayCase.all
    )
    func turnedInMarkup(turnCase: TurnAwayCase) async {
        let flow = await makeFlow(heldIn: turnCase.shotIn)
        flow.showReview()
        await flow.startMarkup()
        sensor.simulate(.upright(in: turnCase.turnedTo))
        expectUpright(flow)
        flow.markup.cancel()
        expectUpright(flow)
        await flow.showShooting()
        #expect(flow.elementRotation.orientation == turnCase.turnedTo)
        flow.photoSet.discard()
    }

    @Test("The review opened again after a turn stands upright", arguments: TurnAwayCase.all)
    func reviewAgain(turnCase: TurnAwayCase) async {
        let flow = await makeFlow(heldIn: turnCase.shotIn)
        flow.showReview()
        await flow.showShooting()
        sensor.simulate(.upright(in: turnCase.turnedTo))
        #expect(flow.elementRotation.orientation == turnCase.turnedTo)
        flow.showReview()
        expectUpright(flow)
        flow.photoSet.discard()
    }

    // MARK: - An interface that turns

    @Test(
        "An interface that turns with the phone keeps every mode upright",
        arguments: CameraOrientation.allCases
    )
    func interfaceTurnsWithThePhone(orientation: CameraOrientation) async {
        let flow = await makeFlow(heldIn: orientation)
        flow.camera.orientation.interfaceOrientationChanged(to: orientation)
        expectUpright(flow)
        flow.showReview()
        expectUpright(flow)
        await flow.showShooting()
        expectUpright(flow)
        flow.photoSet.discard()
    }
}
