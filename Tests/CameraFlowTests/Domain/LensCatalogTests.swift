//
//  LensCatalogTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

@Suite("Lens catalogue")
struct LensCatalogTests {
    static let tripleCamera = LensOptics(
        lenses: [
            LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: 13),
            LensOptics.PhysicalLens(deviceFactor: 2, cropFactors: [2], focalLength: 24),
            LensOptics.PhysicalLens(deviceFactor: 8, cropFactors: [2], focalLength: 100)
        ],
        displayMultiplier: 0.5,
        maximumDeviceFactor: 240,
        recommendedMaximumDeviceFactor: nil
    )

    @Test("A triple camera with 48 MP sensors shows .5 1 2 4 8 and zooms to 40")
    func tripleCamera() {
        let capabilities = LensCatalog.capabilities(position: .back, optics: Self.tripleCamera)
        #expect(capabilities.lenses.map(\.factor) == [0.5, 1, 2, 4, 8])
        #expect(capabilities.lenses.map(\.focalLength) == [13, 24, nil, 100, nil])
        #expect(capabilities.zoomRange == 0.5...40)
        #expect(capabilities.markedFactors == [1.2, 1.5])
    }

    @Test("A crop on a fractional factor adds no button")
    func fractionalCrop() {
        let optics = LensOptics(
            lenses: [
                LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [1.6], focalLength: 13),
                LensOptics.PhysicalLens(deviceFactor: 2, cropFactors: [2], focalLength: 24),
                LensOptics.PhysicalLens(deviceFactor: 8, cropFactors: [2], focalLength: 100)
            ],
            displayMultiplier: 0.5,
            maximumDeviceFactor: 240,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .back, optics: optics)
        #expect(capabilities.lenses.map(\.factor) == [0.5, 1, 2, 4, 8])
    }

    @Test("A crop that reaches the next lens adds no button")
    func cropAtNextLens() {
        let optics = LensOptics(
            lenses: [
                LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [2], focalLength: 13),
                LensOptics.PhysicalLens(deviceFactor: 2, cropFactors: [], focalLength: 26)
            ],
            displayMultiplier: 0.5,
            maximumDeviceFactor: 20,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .back, optics: optics)
        #expect(capabilities.lenses.map(\.factor) == [0.5, 1])
        #expect(capabilities.zoomRange == 0.5...5)
        #expect(capabilities.markedFactors.isEmpty)
    }

    @Test("A single camera has one lens and five times digital zoom at most")
    func singleCamera() {
        let optics = LensOptics(
            lenses: [LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: nil)],
            displayMultiplier: 1,
            maximumDeviceFactor: 3,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .front, optics: optics)
        #expect(capabilities.lenses == [CameraLens(factor: 1, focalLength: nil)])
        #expect(capabilities.zoomRange == 1...3)
    }

    @Test(
        "The dial reaches as far as the zoom range the system recommends, within the device, and the longest lens",
        arguments: [
            (CGFloat(60), CGFloat(30)),
            (CGFloat(400), CGFloat(120)),
            (CGFloat(10), CGFloat(8))
        ]
    )
    func recommendedReach(recommendedDeviceFactor: CGFloat, highest: CGFloat) {
        let optics = LensOptics(
            lenses: Self.tripleCamera.lenses,
            displayMultiplier: 0.5,
            maximumDeviceFactor: 240,
            recommendedMaximumDeviceFactor: recommendedDeviceFactor
        )
        let capabilities = LensCatalog.capabilities(position: .back, optics: optics)
        #expect(capabilities.lenses.map(\.factor) == [0.5, 1, 2, 4, 8])
        #expect(capabilities.zoomRange == 0.5...highest)
    }
}

@Suite("Zoom factor titles")
struct ZoomFactorTitleTests {
    static let english = Locale(identifier: "en_US")

    private static func localization(_ language: String) -> FlowLocalization {
        FlowLocalization(.specific(Locale.Language(identifier: language)))
    }

    @Test("Lens buttons drop the sign and the leading zero", arguments: [
        (0.5, ".5"), (1.0, "1"), (2.0, "2"), (8.0, "8")
    ])
    func lens(factor: Double, expected: String) {
        #expect(ZoomFactorTitle.lens(factor, locale: Self.english) == expected)
    }

    @Test("Dial labels keep the leading zero that the lens buttons drop", arguments: [
        (0.5, "0.5", ".5"), (1.0, "1", "1"), (2.0, "2", "2"), (40.0, "40", "40")
    ])
    func dial(factor: Double, dialLabel: String, lensTitle: String) {
        #expect(ZoomFactorTitle.dial(factor, locale: Self.english) == dialLabel)
        #expect(ZoomFactorTitle.lens(factor, locale: Self.english) == lensTitle)
    }

    @Test("The current zoom is cut to one decimal and carries the sign", arguments: [
        (0.5, "0.5×"), (1.0, "1×"), (2.99, "2.9×"), (21.25, "21.2×"), (40.0, "40×")
    ])
    func current(factor: Double, expected: String) {
        #expect(ZoomFactorTitle.current(factor, localization: Self.localization("en")) == expected)
    }

    @Test(
        "The current zoom takes the form the stock camera writes in the flow's language",
        arguments: [
            ("es", "x2"), ("ru", "2\u{00A0}×"), ("nb", "2\u{00A0}×"), ("sv", "2 ×"), ("lt", "×\u{00A0}2"),
            ("he", "\u{2068}2×\u{2069}"), ("ar", "\u{2068}٢×\u{2069}"), ("uk", "2×"), ("de", "2×")
        ]
    )
    func currentForm(language: String, expected: String) {
        #expect(ZoomFactorTitle.current(2, localization: Self.localization(language)) == expected)
    }

    @Test("The decimal separator follows the locale")
    func locale() {
        let ukrainian = Locale(identifier: "uk_UA")
        #expect(ZoomFactorTitle.lens(0.5, locale: ukrainian) == ",5")
        #expect(ZoomFactorTitle.dial(0.5, locale: ukrainian) == "0,5")
    }
}
