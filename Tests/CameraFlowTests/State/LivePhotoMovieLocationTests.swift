//
//  LivePhotoMovieLocationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The Live Photo movie reaches the app as the camera wrote it, so the shutter asks for the location in the movie
/// only where the app receives the metadata of its photos.
@MainActor
@Suite("The location of a Live Photo movie", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LivePhotoMovieLocationTests {

    @Test(
        "A photo asks for its location in its movie only where the output keeps the metadata",
        arguments: [(CameraFlowOutputMetadata.kept, true), (.stripped, false)]
    )
    func movieLocation(metadata: CameraFlowOutputMetadata, locatesMovie: Bool) async throws {
        let service = RecordingCameraService()
        var output = CameraFlowOutput()
        output.metadata = metadata
        let location = LocationFixture.location()
        let provider: () -> CLLocation? = { location }
        var initialState = CameraFlowInitialState()
        initialState.isLivePhotoEnabled = CameraFlowSetting(true)
        let model = makeCaptureModel(
            service: service,
            initialState: initialState,
            output: output,
            locationProvider: provider
        )
        await model.start()
        await model.capture()
        let request = try #require(service.captureRequests.first)
        #expect(request.isLivePhotoEnabled)
        #expect(request.location == location)
        #expect(request.locatesLivePhotoMovie == locatesMovie)
    }
}
