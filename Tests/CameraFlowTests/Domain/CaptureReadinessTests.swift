//
//  CaptureReadinessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The readiness of two cameras that take one photo together, as the back and the front camera of the pair do.
@Suite("The readiness of cameras that take one photo together")
struct CaptureReadinessTests {
    /// Every readiness, from ready to the furthest from it.
    static let byDistance: [CaptureReadiness] = [
        .ready, .notReadyMomentarily, .waitingForCapture, .waitingForProcessing, .notRunning
    ]

    @Test(
        "Two cameras are ready only when both are, and otherwise as far from ready as the one further from it",
        arguments: byDistance.indices, byDistance.indices
    )
    func combined(first: Int, second: Int) {
        let readiness = Self.byDistance[first].combined(with: Self.byDistance[second])
        #expect(readiness == Self.byDistance[max(first, second)])
    }
}
