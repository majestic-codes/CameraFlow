//
//  CameraFlowPhotoLocationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("The location of the photos in the configuration")
struct CameraFlowPhotoLocationTests {

    @Test("The photos record their location by default, and the flow asks for it")
    func defaults() {
        let configuration = CameraFlowConfiguration()
        #expect(configuration.photoLocation == .automatic)
        #expect(configuration.asksForLocation)
    }

    @Test(
        "The flow asks only for the automatic location",
        arguments: [
            (CameraFlowPhotoLocation.automatic, true),
            (.appRequestsAccess, false),
            (.off, false)
        ]
    )
    func asks(photoLocation: CameraFlowPhotoLocation, asks: Bool) {
        var configuration = CameraFlowConfiguration()
        configuration.photoLocation = photoLocation
        #expect(configuration.asksForLocation == asks)
        #expect(configuration != CameraFlowConfiguration() || photoLocation == .automatic)
    }

    @Test("A location provider goes with every location that records one", arguments: [true, false])
    func providerAccepted(hasLocationProvider: Bool) {
        var configuration = CameraFlowConfiguration()
        configuration.validate(hasLocationProvider: hasLocationProvider)
        configuration.photoLocation = .appRequestsAccess
        configuration.validate(hasLocationProvider: hasLocationProvider)
        configuration.photoLocation = .off
        configuration.validate(hasLocationProvider: false)
    }

    #if os(macOS)
    @Test("A location provider with the location off stops the program")
    func providerRefused() async {
        await #expect(processExitsWith: .failure) {
            var configuration = CameraFlowConfiguration()
            configuration.photoLocation = .off
            configuration.validate(hasLocationProvider: true)
        }
    }
    #endif
}
