//
//  FlowInterfaceOrientationsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("The interface orientations of the flow")
struct FlowInterfaceOrientationsTests {

    @Test(
        "An app with portrait gets the flow in portrait only",
        arguments: [
            [InterfaceQuarter.portrait],
            [.landscapeLeft, .portrait, .landscapeRight],
            InterfaceQuarter.allCases
        ]
    )
    func portraitApp(appQuarters: [InterfaceQuarter]) {
        let orientations = FlowInterfaceOrientations(appQuarters: appQuarters)
        #expect(orientations.quarters == [.portrait])
        #expect(orientations.preferred == .portrait)
    }

    @Test("An app that lists no orientation has the system's default, which holds portrait")
    func appWithoutList() {
        let orientations = FlowInterfaceOrientations(appQuarters: [])
        #expect(orientations.quarters == [.portrait])
        #expect(orientations.preferred == .portrait)
    }

    @Test("An app without portrait keeps its own orientations, and the flow opens in the first it lists")
    func appWithoutPortrait() {
        let orientations = FlowInterfaceOrientations(appQuarters: [.landscapeRight, .landscapeLeft])
        #expect(orientations.quarters == [.landscapeRight, .landscapeLeft])
        #expect(orientations.preferred == .landscapeRight)
    }

    @Test("The names of the Info.plist are read in their order")
    func names() throws {
        let names = [
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeRight"
        ]
        let quarters = try FlowInterfaceOrientations.quarters(named: names)
        #expect(quarters == [.landscapeLeft, .portraitUpsideDown, .portrait, .landscapeRight])
    }

    @Test("A name that is no interface orientation fails loud")
    func unknownName() {
        let names = ["UIInterfaceOrientationPortrait", "UIDeviceOrientationFaceUp"]
        #expect(throws: UnknownInterfaceOrientation(name: "UIDeviceOrientationFaceUp")) {
            try FlowInterfaceOrientations.quarters(named: names)
        }
    }
}
