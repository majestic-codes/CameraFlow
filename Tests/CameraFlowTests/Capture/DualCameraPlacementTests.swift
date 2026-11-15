//
//  DualCameraPlacementTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Dual camera placement")
struct DualCameraPlacementTests {
    /// The top trailing corner of the unit square, a fifth of it wide and a tenth tall.
    private static let corner = CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.1)

    @Test(
        "A quarter turn clockwise takes the top trailing corner round the square",
        arguments: [
            (0, CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.1)),
            (1, CGRect(x: 0.8, y: 0.7, width: 0.1, height: 0.2)),
            (2, CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.1)),
            (3, CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.2)),
            (4, CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.1)),
            (-1, CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.2))
        ]
    )
    func turns(quarterTurns: Int, expected: CGRect) {
        let turned = DualCameraPlacement.turned(Self.corner, quarterTurns: quarterTurns)
        expectClose(turned, expected, tolerance: 0.001)
    }

    @Test("A portrait photo takes the circle at the place and the size of the viewfinder")
    func portrait() {
        let region = CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)
        let square = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 0,
            isViewfinderMirrored: false,
            framedRegion: nil,
            photoSize: CGSize(width: 3024, height: 4032)
        )
        expectClose(square, CGRect(x: 1814.4, y: 201.6, width: 907.2, height: 907.2), tolerance: 0.001)
    }

    @Test("A photo of a camera the viewfinder mirrored takes the circle at the mirrored place, over the same picture")
    func mirroredViewfinder() {
        let region = CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)
        let portrait = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 0,
            isViewfinderMirrored: true,
            framedRegion: nil,
            photoSize: CGSize(width: 3024, height: 4032)
        )
        expectClose(portrait, CGRect(x: 302.4, y: 201.6, width: 907.2, height: 907.2), tolerance: 0.001)
        let landscape = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 3,
            isViewfinderMirrored: true,
            framedRegion: nil,
            photoSize: CGSize(width: 4032, height: 3024)
        )
        expectClose(landscape, CGRect(x: 2923.2, y: 302.4, width: 907.2, height: 907.2), tolerance: 0.001)
    }

    @Test("A photo taken with the top of the phone to the left has the circle in its top leading corner")
    func landscape() {
        let region = CGRect(x: 0.6, y: 0.05, width: 0.3, height: 0.225)
        let square = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 3,
            isViewfinderMirrored: false,
            framedRegion: nil,
            photoSize: CGSize(width: 4032, height: 3024)
        )
        expectClose(square, CGRect(x: 201.6, y: 302.4, width: 907.2, height: 907.2), tolerance: 0.001)
    }

    @Test("A framed region narrows the photo to what the viewfinder showed")
    func framed() {
        let region = CGRect(x: 0.5, y: 0.5, width: 0.25, height: 0.25)
        let framed = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        let square = DualCameraPlacement.circleRectangle(
            region: region,
            quarterTurns: 0,
            isViewfinderMirrored: false,
            framedRegion: framed,
            photoSize: CGSize(width: 800, height: 400)
        )
        expectClose(square, CGRect(x: 400, y: 200, width: 100, height: 100), tolerance: 0.001)
    }

    @Test(
        "The back camera's capture angle tells the quarter turns from the viewfinder to the upright photo",
        arguments: [
            (CGFloat(90), 0, "portrait"),
            (0, 3, "top of the phone to the left"),
            (180, 1, "top of the phone to the right"),
            (270, 2, "upside down"),
            (-90, 2, "upside down, counted the other way")
        ]
    )
    func quarterTurns(captureAngle: CGFloat, expectedTurns: Int, hold: String) {
        let turns = DualCameraPlacement.quarterTurns(captureAngle: captureAngle, portraitAngle: 90)
        #expect(turns == expectedTurns, "\(hold)")
    }

    @Test("The front camera is mirrored on screen in either place, the back camera never, and no photo is")
    func mirroring() {
        #expect(CameraPosition.front.isMirroredOnScreen)
        #expect(CameraPosition.back.isMirroredOnScreen == false)
    }
}
