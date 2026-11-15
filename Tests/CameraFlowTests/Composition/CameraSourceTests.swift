//
//  CameraSourceTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("The camera a flow runs on")
struct CameraSourceTests {

    @Test(
        "A device runs its own camera, and the simulated one only when the app asks; the simulator is simulated",
        arguments: [
            (false, false, CameraSource.device),
            (true, false, .simulated),
            (false, true, .simulated),
            (true, true, .simulated)
        ]
    )
    func resolve(usesSimulatedCamera: Bool, isSimulator: Bool, source: CameraSource) {
        #expect(CameraSource.resolve(usesSimulatedCamera: usesSimulatedCamera, isSimulator: isSimulator) == source)
    }

    @Test("Without the app asking, the flow runs the simulated camera in the simulator and the device's own elsewhere")
    func environment() {
        #if targetEnvironment(simulator)
        #expect(CameraSource.resolve(usesSimulatedCamera: false) == .simulated)
        #else
        #expect(CameraSource.resolve(usesSimulatedCamera: false) == .device)
        #endif
    }
}
