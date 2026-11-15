//
//  LocationRecordingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// Whether the photos of a flow can carry a location, which decides whether the flow follows and asks for one.
@Suite("Photos that can carry a location")
struct LocationRecordingTests {

    @Test(
        "Photos carry a location where the files keep their metadata or the flow may save to the library",
        arguments: [
            (CameraFlowOutputMetadata.kept, false, true),
            (.kept, true, true),
            (.stripped, true, true),
            (.stripped, false, false)
        ]
    )
    func carriers(metadata: CameraFlowOutputMetadata, savesToLibrary: Bool, canCarry: Bool) {
        var configuration = CameraFlowConfiguration()
        configuration.output.metadata = metadata
        configuration.photoLibrarySaving.isEnabled = savesToLibrary ? CameraFlowSetting(false) : .fixed(false)
        #expect(configuration.canCarryLocation == canCarry)
    }
}
