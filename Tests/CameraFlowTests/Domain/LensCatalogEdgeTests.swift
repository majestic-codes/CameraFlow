//
//  LensCatalogEdgeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Lens catalog: devices with one lens, no main lens or no lens at all")
struct LensCatalogEdgeTests {

    @Test("A single 24 mm camera marks both framings of its main lens: no longer lens cuts them off")
    func singleMainLens() {
        let optics = LensOptics(
            lenses: [LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: 24)],
            displayMultiplier: 1,
            maximumDeviceFactor: 10,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .back, optics: optics)
        #expect(capabilities.lenses.map(\.factor) == [1])
        #expect(capabilities.markedFactors == [1.2, 1.5])
        #expect(capabilities.zoomRange == 1...5)
    }

    @Test("A device whose lenses show no factor of one has no main lens to mark")
    func noMainLens() {
        let optics = LensOptics(
            lenses: [LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: 24)],
            displayMultiplier: 0.5,
            maximumDeviceFactor: 6,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .back, optics: optics)
        #expect(capabilities.lenses.map(\.factor) == [0.5])
        #expect(capabilities.markedFactors.isEmpty)
        #expect(capabilities.zoomRange == 0.5...2.5)
    }

    @Test("A device that reports no lens has no button and a range of the one factor")
    func noLens() {
        let optics = LensOptics(
            lenses: [],
            displayMultiplier: 1,
            maximumDeviceFactor: 4,
            recommendedMaximumDeviceFactor: nil
        )
        let capabilities = LensCatalog.capabilities(position: .front, optics: optics)
        #expect(capabilities.lenses.isEmpty)
        #expect(capabilities.markedFactors.isEmpty)
        #expect(capabilities.zoomRange == 1...4)
    }
}
