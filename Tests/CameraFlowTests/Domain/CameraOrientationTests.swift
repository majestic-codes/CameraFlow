//
//  CameraOrientationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Camera orientation")
struct CameraOrientationTests {

    @Test("The quarter of an angle rounds to whole quarter turns either way", arguments: [
        (0.0, CameraOrientation.portrait), (90, .landscapeLeft), (-90, .landscapeRight), (180, .upsideDown),
        (-180, .upsideDown), (270, .landscapeRight), (-270, .landscapeLeft), (360, .portrait), (450, .landscapeLeft),
        (44, .portrait), (46, .landscapeLeft)
    ])
    func quarterOfAngle(degrees: Double, expected: CameraOrientation) {
        #expect(CameraOrientation(elementAngle: degrees) == expected)
    }

    @Test("Every quarter is its own element angle", arguments: CameraOrientation.allCases)
    func roundTrip(orientation: CameraOrientation) {
        #expect(CameraOrientation(elementAngle: orientation.elementAngle) == orientation)
    }

    @Test("The phone as seen from the interface", arguments: RelativeOrientationCase.all)
    func relative(relativeCase: RelativeOrientationCase) {
        #expect(relativeCase.held.relative(to: relativeCase.interface) == relativeCase.relative)
        #expect(relativeCase.relative.turned(by: relativeCase.interface) == relativeCase.held)
    }

    @Test("Turning goes the shortest way and never wraps")
    func shortestPath() {
        let path: [CameraOrientation] = [
            .landscapeLeft, .portrait, .landscapeRight, .upsideDown, .landscapeLeft, .portrait, .upsideDown
        ]
        var rotation = CameraElementRotation.portrait
        var degrees: [Double] = []
        for orientation in path {
            rotation = rotation.turned(to: orientation)
            degrees.append(rotation.degrees)
        }
        #expect(degrees == [90, 0, -90, -180, -270, -360, -180])
        #expect(rotation.orientation == .upsideDown)
    }

    @Test("Turning to the same quarter changes nothing")
    func sameQuarter() {
        let rotation = CameraElementRotation.portrait.turned(to: .landscapeRight)
        #expect(rotation.turned(to: .landscapeRight) == rotation)
    }

    @Test("A block that only flips stays put in landscape and turns half a turn upside down")
    func halfTurn() {
        let left = CameraElementRotation.portrait.turned(to: .landscapeLeft)
        let down = left.turned(to: .upsideDown)
        let right = down.turned(to: .landscapeRight)
        #expect(left.halfTurnDegrees == 0)
        #expect(down.halfTurnDegrees == 180)
        #expect(right.halfTurnDegrees == 360)
        #expect(right.turned(to: .portrait).halfTurnDegrees == 360)
    }
}
