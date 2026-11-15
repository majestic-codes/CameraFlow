//
//  DeviceGravityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The quarter the phone is held in, from gravity")
struct DeviceGravityTests {
    struct QuarterCase: Sendable, CustomTestStringConvertible {
        let gravity: DeviceGravity
        let orientation: CameraOrientation

        var testDescription: String {
            "\(orientation)"
        }
    }

    /// A phone held in a quarter, then turned in the plane of its screen and leaned away from upright.
    struct HoldCase: Sendable, CustomTestStringConvertible {
        let held: CameraOrientation
        let elementAngle: Double
        var lean = 0.0
        let expected: CameraOrientation

        var resolved: CameraOrientation {
            DeviceGravityTests.gravity(elementAngle: elementAngle, lean: lean).orientation(holding: held)
        }

        var testDescription: String {
            "\(held) turned to \(elementAngle), leaning \(lean)"
        }
    }

    /// Gravity on a phone whose elements turn `elementAngle` degrees clockwise on the portrait screen to point
    /// straight up, and whose screen leans `lean` degrees back from upright, or forward when negative.
    private static func gravity(elementAngle: Double, lean: Double) -> DeviceGravity {
        let turn = elementAngle * .pi / 180
        let tilt = lean * .pi / 180
        return DeviceGravity(
            towardRightEdge: -sin(turn) * cos(tilt),
            towardTopEdge: -cos(turn) * cos(tilt),
            outOfScreen: -sin(tilt)
        )
    }

    /// The quarters a phone passes through, starting in portrait, as one reading follows another.
    private static func path(through readings: [DeviceGravity]) -> [CameraOrientation] {
        var held = CameraOrientation.portrait
        return readings.map { gravity in
            held = gravity.orientation(holding: held)
            return held
        }
    }

    private static let faceUp = DeviceGravity(towardRightEdge: 0, towardTopEdge: 0, outOfScreen: -1)
    private static let faceDown = DeviceGravity(towardRightEdge: 0, towardTopEdge: 0, outOfScreen: 1)
    private static let weightless = DeviceGravity(towardRightEdge: 0, towardTopEdge: 0, outOfScreen: 0)

    // MARK: - The four quarters

    @Test(
        "Gravity towards an edge gives the quarter of that edge, whatever was held",
        arguments: [
            QuarterCase(
                gravity: DeviceGravity(towardRightEdge: 0, towardTopEdge: -1, outOfScreen: 0),
                orientation: .portrait
            ),
            QuarterCase(
                gravity: DeviceGravity(towardRightEdge: -1, towardTopEdge: 0, outOfScreen: 0),
                orientation: .landscapeLeft
            ),
            QuarterCase(
                gravity: DeviceGravity(towardRightEdge: 1, towardTopEdge: 0, outOfScreen: 0),
                orientation: .landscapeRight
            ),
            QuarterCase(
                gravity: DeviceGravity(towardRightEdge: 0, towardTopEdge: 1, outOfScreen: 0),
                orientation: .upsideDown
            )
        ],
        CameraOrientation.allCases
    )
    func quarter(of quarterCase: QuarterCase, held: CameraOrientation) {
        #expect(quarterCase.gravity.orientation(holding: held) == quarterCase.orientation)
    }

    @Test(
        "The gravity of a phone upright in a quarter gives that quarter back",
        arguments: CameraOrientation.allCases,
        CameraOrientation.allCases
    )
    func uprightRoundTrip(of orientation: CameraOrientation, held: CameraOrientation) {
        #expect(DeviceGravity.upright(in: orientation).orientation(holding: held) == orientation)
    }

    // MARK: - Boundaries

    @Test(
        "The held quarter stays until the phone is turned 5 degrees past its 45 degree boundary",
        arguments: [
            HoldCase(held: .portrait, elementAngle: 44, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 46, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 49, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 51, expected: .landscapeLeft),
            HoldCase(held: .portrait, elementAngle: -49, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: -51, expected: .landscapeRight),
            HoldCase(held: .landscapeLeft, elementAngle: 41, expected: .landscapeLeft),
            HoldCase(held: .landscapeLeft, elementAngle: 39, expected: .portrait),
            HoldCase(held: .landscapeLeft, elementAngle: 139, expected: .landscapeLeft),
            HoldCase(held: .landscapeLeft, elementAngle: 141, expected: .upsideDown),
            HoldCase(held: .landscapeRight, elementAngle: -41, expected: .landscapeRight),
            HoldCase(held: .landscapeRight, elementAngle: -39, expected: .portrait),
            HoldCase(held: .landscapeRight, elementAngle: -139, expected: .landscapeRight),
            HoldCase(held: .landscapeRight, elementAngle: -141, expected: .upsideDown),
            HoldCase(held: .upsideDown, elementAngle: 131, expected: .upsideDown),
            HoldCase(held: .upsideDown, elementAngle: 129, expected: .landscapeLeft),
            HoldCase(held: .upsideDown, elementAngle: -131, expected: .upsideDown),
            HoldCase(held: .upsideDown, elementAngle: -129, expected: .landscapeRight)
        ]
    )
    func heldQuarter(of holdCase: HoldCase) {
        #expect(holdCase.resolved == holdCase.expected)
    }

    @Test(
        "A phone turned out of its quarter goes to the nearest one, with the boundaries at 45 degrees",
        arguments: [
            HoldCase(held: .portrait, elementAngle: 134, expected: .landscapeLeft),
            HoldCase(held: .portrait, elementAngle: 136, expected: .upsideDown),
            HoldCase(held: .portrait, elementAngle: -134, expected: .landscapeRight),
            HoldCase(held: .portrait, elementAngle: -136, expected: .upsideDown),
            HoldCase(held: .landscapeRight, elementAngle: 44, expected: .portrait),
            HoldCase(held: .landscapeRight, elementAngle: 46, expected: .landscapeLeft),
            HoldCase(held: .landscapeLeft, elementAngle: -44, expected: .portrait),
            HoldCase(held: .landscapeLeft, elementAngle: -46, expected: .landscapeRight),
            HoldCase(held: .upsideDown, elementAngle: 44, expected: .portrait),
            HoldCase(held: .upsideDown, elementAngle: 46, expected: .landscapeLeft),
            HoldCase(held: .upsideDown, elementAngle: -44, expected: .portrait),
            HoldCase(held: .upsideDown, elementAngle: -46, expected: .landscapeRight)
        ]
    )
    func nearestQuarter(of holdCase: HoldCase) {
        #expect(holdCase.resolved == holdCase.expected)
    }

    @Test("A phone that wavers on a boundary does not flicker between two quarters")
    func wavering() {
        let elementAngles: [Double] = [44, 46, 44, 46, 49, 51, 46, 44, 46, 41, 39, 44, 46]
        let path = Self.path(through: elementAngles.map { Self.gravity(elementAngle: $0, lean: 0) })
        let portrait = CameraOrientation.portrait
        let landscape = CameraOrientation.landscapeLeft
        #expect(path == [
            portrait, portrait, portrait, portrait, portrait,
            landscape, landscape, landscape, landscape, landscape,
            portrait, portrait, portrait
        ])
    }

    // MARK: - Lying flat and leaning

    @Test(
        "A phone lying on either face keeps the quarter it was held in",
        arguments: [faceUp, faceDown, weightless],
        CameraOrientation.allCases
    )
    func lyingFlat(gravity: DeviceGravity, held: CameraOrientation) {
        #expect(gravity.orientation(holding: held) == held)
    }

    @Test(
        "A phone that leans up to 45 degrees is still turned, and one that leans further keeps its quarter",
        arguments: [
            HoldCase(held: .portrait, elementAngle: 90, lean: 44, expected: .landscapeLeft),
            HoldCase(held: .portrait, elementAngle: 90, lean: -44, expected: .landscapeLeft),
            HoldCase(held: .landscapeRight, elementAngle: 180, lean: 44, expected: .upsideDown),
            HoldCase(held: .portrait, elementAngle: 90, lean: 46, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 90, lean: -46, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 90, lean: 70, expected: .portrait),
            HoldCase(held: .portrait, elementAngle: 90, lean: -70, expected: .portrait),
            HoldCase(held: .landscapeLeft, elementAngle: 0, lean: 85, expected: .landscapeLeft),
            HoldCase(held: .landscapeLeft, elementAngle: 0, lean: -85, expected: .landscapeLeft),
            HoldCase(held: .upsideDown, elementAngle: -90, lean: 89, expected: .upsideDown)
        ]
    )
    func leaning(of holdCase: HoldCase) {
        #expect(holdCase.resolved == holdCase.expected)
    }

    @Test("A phone picked up from the table turns once it stands upright enough")
    func pickedUp() {
        let leans: [Double] = [90, 70, 50, 40, 10]
        let path = Self.path(through: leans.map { Self.gravity(elementAngle: -90, lean: $0) })
        #expect(path == [.portrait, .portrait, .portrait, .landscapeRight, .landscapeRight])
    }
}
