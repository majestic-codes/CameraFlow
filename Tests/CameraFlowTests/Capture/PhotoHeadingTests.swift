//
//  PhotoHeadingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

/// The direction the camera pointed in: which compass readings count, how the GPS dictionary writes it, and that a
/// photo is taken with it, without it and never held back by it.
@MainActor
@Suite("The direction of the camera in a photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoHeadingTests {
    nonisolated private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let east = PhotoHeading(degrees: 90, north: .geographic)

    // MARK: - The setting

    @Test("The direction is off by default")
    func offByDefault() {
        #expect(CameraFlowConfiguration().photoDirection == .off)
    }

    // MARK: - GPS dictionary

    @Test("The direction is the image direction and the destination bearing with its north, apart from the course")
    func dictionaryWithLocation() throws {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: 200,
            speed: 1,
            timestamp: Self.now
        )
        let heading = PhotoHeading(degrees: 75.5, north: .magnetic)
        let gps = PhotoLocationMetadata.gpsDictionary(location: location, heading: heading)
        #expect(gps[kCGImagePropertyGPSImgDirection] as? Double == 75.5)
        #expect(gps[kCGImagePropertyGPSImgDirectionRef] as? String == "M")
        #expect(gps[kCGImagePropertyGPSDestBearing] as? Double == 75.5)
        #expect(gps[kCGImagePropertyGPSDestBearingRef] as? String == "M")
        #expect(gps[kCGImagePropertyGPSTrack] as? Double == 200)
        #expect(gps[kCGImagePropertyGPSTrackRef] as? String == "T")
    }

    @Test("A direction without a location makes a dictionary with the direction only, and neither makes none")
    func dictionaryWithoutLocation() throws {
        let gps = PhotoLocationMetadata.gpsDictionary(location: nil, heading: Self.east)
        #expect(gps.count == 4)
        #expect(gps[kCGImagePropertyGPSImgDirectionRef] as? String == "T")
        #expect(gps[kCGImagePropertyGPSDestBearingRef] as? String == "T")
        #expect(PhotoLocationMetadata.gpsDictionary(location: nil, heading: nil).isEmpty)
        let location = LocationFixture.location(latitude: -33.86, longitude: 151.21)
        let locationOnly = PhotoLocationMetadata.gpsDictionary(location: location, heading: nil)
        #expect(locationOnly[kCGImagePropertyGPSImgDirection] == nil)
        #expect(locationOnly[kCGImagePropertyGPSDestBearing] == nil)
    }

    // MARK: - Photos

    /// The GPS tags of a capture's file, none for a file without the GPS dictionary.
    private func gpsTags(of capture: CameraCapture) throws -> [CFString: Any] {
        let properties = try ImageFile.properties(of: capture.fileURL)
        guard let gps = properties[kCGImagePropertyGPSDictionary] else { return [:] }
        return try #require(gps as? [CFString: Any])
    }

    @Test("The heading at the shutter goes into the file, with the location and without one")
    func photoWithHeading() async throws {
        let service = RecordingCameraService()
        let compass = FakeHeading(heading: Self.east)
        var captures: [CameraCapture] = []
        let location = LocationFixture.location(latitude: -33.86, longitude: 151.21)
        var providesLocation = true
        let model = makeCaptureModel(
            service: service,
            heading: compass,
            onCapture: { captures.append($0) },
            locationProvider: { providesLocation ? location : nil }
        )
        await model.start()
        #expect(compass.followCalls == [true])
        await model.capture()
        providesLocation = false
        await model.capture()
        try #require(captures.count == 2)
        let located = try gpsTags(of: captures[0])
        let unlocated = try gpsTags(of: captures[1])
        #expect(located[kCGImagePropertyGPSLatitudeRef] as? String == "S")
        #expect(located[kCGImagePropertyGPSImgDirection] as? Double == 90)
        #expect(located[kCGImagePropertyGPSDestBearing] as? Double == 90)
        #expect(unlocated[kCGImagePropertyGPSLatitudeRef] == nil)
        #expect(unlocated[kCGImagePropertyGPSImgDirectionRef] as? String == "T")
        #expect(unlocated[kCGImagePropertyGPSDestBearingRef] as? String == "T")
        model.stop()
        #expect(compass.followCalls == [true, false])
        try captures.forEach(CaptureTestSupport.discardFiles)
    }

    @Test("Without a reading the photo is taken and handed over without a direction")
    func photoWithoutHeading() async throws {
        let service = RecordingCameraService()
        let compass = FakeHeading(heading: nil)
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(service: service, heading: compass) { captures.append($0) }
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        #expect(compass.readCount == 1)
        #expect(try gpsTags(of: capture).isEmpty)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("The compass follows the quarter the phone is held in")
    func followsOrientation() async {
        let service = RecordingCameraService()
        let sensor = ManualAttitudeSensor()
        let compass = FakeHeading()
        let model = makeCaptureModel(service: service, attitudeSensor: sensor, heading: compass)
        await model.start()
        sensor.simulate(.upright(in: .landscapeLeft))
        #expect(compass.orientations.last == .landscapeLeft)
        model.stop()
    }

    @Test("A RAW photo keeps its file as the camera wrote it, without the direction")
    func rawWithoutHeading() async throws {
        let store = CaptureTestSupport.makeFileStore()
        let photo = CapturedPhoto(
            imageData: try DevicePhotoFixture.makeCameraFile(),
            encoding: .appleProRAW,
            livePhotoMovieURL: nil
        )
        var pipeline = PhotoCapturePipeline(aspectRatio: .fourByThree, output: CameraFlowOutput(), store: store)
        pipeline.heading = Self.east
        let capture = try await pipeline.process(photo)
        #expect(try Data(contentsOf: capture.fileURL) == photo.imageData)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
