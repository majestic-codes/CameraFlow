//
//  OrientationModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Element rotation in the model", .temporaryDirectory, .timeLimit(.minutes(1)))
struct OrientationModelTests {
    let service = RecordingCameraService()
    let sensor = ManualAttitudeSensor()

    struct FixtureCase: Sendable {
        let orientation: CameraOrientation
        let degrees: Double
    }

    private static let faceUp = DeviceGravity(towardRightEdge: 0, towardTopEdge: 0, outOfScreen: -1)

    // MARK: - The orientation alone

    @Test("The orientation turns the elements by how the phone is held as seen from the interface")
    func orientationAlone() {
        let orientation = OrientationModel()
        orientation.gravityChanged(to: .upright(in: .landscapeLeft))
        #expect(orientation.heldOrientation == .landscapeLeft)
        #expect(orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
        orientation.interfaceOrientationChanged(to: .landscapeLeft)
        #expect(orientation.interfaceOrientation == .landscapeLeft)
        #expect(orientation.elementRotation == CameraElementRotation(orientation: .portrait, degrees: 0))
    }

    @Test("The heading takes the quarter the phone is held in from the camera model")
    func headingFollowsTheHeldQuarter() async {
        let heading = FakeHeading()
        let model = makeCaptureModel(service: service, attitudeSensor: sensor, heading: heading)
        await model.start()
        sensor.simulate(.upright(in: .landscapeRight))
        #expect(model.orientation.heldOrientation == .landscapeRight)
        #expect(heading.orientations.last == .landscapeRight)
    }

    // MARK: - Turning

    @Test("The elements turn to the quarter gravity shows")
    func followsGravity() async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        #expect(model.orientation.elementRotation == .portrait)
        sensor.simulate(.upright(in: .landscapeLeft))
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
        sensor.simulate(.upright(in: .portrait))
        sensor.simulate(.upright(in: .landscapeRight))
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeRight, degrees: -90))
    }

    @Test("The elements follow the phone while the camera is stopped, as during a visit to the review")
    func followsGravityWhileStopped() async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        model.stop()
        #expect(sensor.isRunning)
        sensor.simulate(.upright(in: .landscapeLeft))
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
        await model.resume()
        #expect(sensor.isRunning)
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
        sensor.simulate(.upright(in: .portrait))
        #expect(model.orientation.elementRotation == .portrait)
    }

    @Test("An interface that turns with the phone leaves the elements upright", arguments: CameraOrientation.allCases)
    func interfaceTurnsWithThePhone(orientation: CameraOrientation) async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        sensor.simulate(.upright(in: orientation))
        model.orientation.interfaceOrientationChanged(to: orientation)
        #expect(model.orientation.elementRotation.orientation == .portrait)
        #expect(model.orientation.interfaceOrientation == orientation)
    }

    @Test("The elements turn by what lies between the phone and the interface", arguments: RelativeOrientationCase.all)
    func turnsRelativeToTheInterface(relativeCase: RelativeOrientationCase) async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        model.orientation.interfaceOrientationChanged(to: relativeCase.interface)
        sensor.simulate(.upright(in: relativeCase.held))
        #expect(model.orientation.elementRotation.orientation == relativeCase.relative)
    }

    @Test("The elements turn the same way with the front camera")
    func frontCamera() async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        await model.flipCamera()
        #expect(model.session.position == .front)
        #expect(model.orientation.elementRotation == .portrait)
        sensor.simulate(.upright(in: .landscapeLeft))
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
        await model.flipCamera()
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .landscapeLeft, degrees: 90))
    }

    @Test("A phone laid flat leaves the elements as they were")
    func laidFlat() async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        sensor.simulate(.upright(in: .upsideDown))
        sensor.simulate(Self.faceUp)
        #expect(model.orientation.elementRotation == CameraElementRotation(orientation: .upsideDown, degrees: 180))
    }

    @Test(
        "The simulated sensor turns the elements to the quarter of its fixture",
        arguments: [
            FixtureCase(orientation: .portrait, degrees: 0),
            FixtureCase(orientation: .landscapeLeft, degrees: 90),
            FixtureCase(orientation: .landscapeRight, degrees: -90),
            FixtureCase(orientation: .upsideDown, degrees: 180)
        ]
    )
    func simulatedOrientation(of fixtureCase: FixtureCase) async {
        let model = PhotoCameraModel(
            service: SimulatedCameraService(scene: .black),
            haptics: RecordingCameraHaptics(),
            attitudeSensor: SimulatedAttitudeSensor(orientation: fixtureCase.orientation)
        ) { _ in }
        await model.start()
        let expected = CameraElementRotation(orientation: fixtureCase.orientation, degrees: fixtureCase.degrees)
        #expect(model.orientation.elementRotation == expected)
    }

    // MARK: - Life of the sensor

    @Test("The sensor runs from the start of the camera until the camera closes")
    func sensorLifetime() async {
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        #expect(sensor.isRunning == false)
        await model.start()
        #expect(sensor.isRunning)
        model.close()
        #expect(sensor.isRunning == false)
    }

    @Test("A camera the user refused leaves the sensor off")
    func refusedCamera() async {
        service.authorization = .denied
        let model = makeCaptureModel(service: service, attitudeSensor: sensor)
        await model.start()
        #expect(sensor.isRunning == false)
    }

    // MARK: - The photo

    @Test("The photo is the camera's own in whichever quarter the elements stand")
    func photoIgnoresElementRotation() async throws {
        let original = try DevicePhotoFixture.make()
        service.deliveredPhoto = CapturedPhoto(
            imageData: original,
            encoding: .heif,
            livePhotoMovieURL: nil
        )
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, attitudeSensor: sensor) { captures.append($0) }
        await model.start()
        await model.capture()
        sensor.simulate(.upright(in: .landscapeLeft))
        await model.capture()
        #expect(model.orientation.elementRotation.orientation == .landscapeLeft)
        let requests = service.captureRequests
        #expect(requests.count == 2)
        #expect(requests.first == requests.last)
        #expect(captures.count == 2)
        for capture in captures {
            #expect(try Data(contentsOf: capture.fileURL) == original)
            try CaptureTestSupport.discardFiles(of: capture)
        }
    }
}
