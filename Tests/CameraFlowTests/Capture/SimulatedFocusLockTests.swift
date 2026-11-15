//
//  SimulatedFocusLockTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// The lock of the focus and the exposure on the camera without hardware, which the simulator and the UI tests run.
@MainActor
@Suite("Simulated focus and exposure lock")
struct SimulatedFocusLockTests {
    private let point = CGPoint(x: 0.3, y: 0.7)

    @Test("A camera that runs settles into the lock at once, alone and as a pair")
    func runningCameraLocks() async throws {
        let service = SimulatedCameraService(scene: .black)
        _ = try await service.start(position: .back)
        #expect(await service.lockFocusAndExposure(atDevicePoint: point))
        _ = try await service.startDualCamera(main: .front)
        #expect(await service.lockFocusAndExposure(atDevicePoint: point))
    }

    @Test("A camera that has not started or was stopped does not lock")
    func stoppedCameraDoesNotLock() async throws {
        let service = SimulatedCameraService(scene: .black)
        #expect(await service.lockFocusAndExposure(atDevicePoint: point) == false)
        _ = try await service.start(position: .back)
        service.stop()
        #expect(await service.lockFocusAndExposure(atDevicePoint: point) == false)
    }
}
