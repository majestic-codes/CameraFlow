//
//  CameraIdentifierTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("The identifiers of the camera screen")
struct CameraIdentifierTests {

    @Test("Lens identifiers do not depend on the locale", arguments: [(0.5, "camera.lens.0.5"), (1.0, "camera.lens.1")])
    func identifier(factor: Double, expected: String) {
        #expect(CameraIdentifier.lens(factor) == expected)
    }
}
