//
//  CameraChangeGateCaptureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// Work the test holds until it lets it go.
@MainActor
private final class HeldWork {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isHeld = false

    func hold() async {
        isHeld = true
        await withCheckedContinuation { continuation = $0 }
        isHeld = false
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

/// The gate between the changes of the camera and the photos it takes, in the order they are asked for.
@MainActor
@Suite("Changes of the camera and captures through one gate", .timeLimit(.minutes(1)))
struct CameraChangeGateCaptureTests {
    let gate = CameraChangeGate()

    @Test("A change asked for while a capture runs waits for it, and counts as a change meanwhile")
    func changeWaitsForCapture() async {
        let capture = HeldWork()
        var order: [String] = []
        let capturing = Task {
            await gate.capture {
                await capture.hold()
                order.append("capture")
            }
        }
        await settle { capture.isHeld }
        #expect(gate.isChanging == false)
        let changing = Task {
            await gate.run {
                order.append("change")
            }
        }
        await settleQueuedWork()
        #expect(gate.isChanging)
        #expect(order.isEmpty)
        capture.release()
        await capturing.value
        await changing.value
        #expect(order == ["capture", "change"])
        #expect(gate.isChanging == false)
    }

    @Test("A capture asked for while a change runs waits for it")
    func captureWaitsForChange() async {
        let change = HeldWork()
        var order: [String] = []
        let changing = Task {
            await gate.run {
                await change.hold()
                order.append("change")
            }
        }
        await settle { change.isHeld }
        let capturing = Task {
            await gate.capture {
                order.append("capture")
            }
        }
        await settleQueuedWork()
        #expect(order.isEmpty)
        change.release()
        await changing.value
        await capturing.value
        #expect(order == ["change", "capture"])
    }

    @Test("A capture asked for after a change that waits for another capture runs after that change")
    func captureAfterWaitingChange() async {
        let firstCapture = HeldWork()
        var order: [String] = []
        let first = Task {
            await gate.capture {
                await firstCapture.hold()
                order.append("first capture")
            }
        }
        await settle { firstCapture.isHeld }
        let changing = Task {
            await gate.run {
                order.append("change")
            }
        }
        await settleQueuedWork()
        let second = Task {
            await gate.capture {
                order.append("second capture")
            }
        }
        await settleQueuedWork()
        #expect(order.isEmpty)
        firstCapture.release()
        await first.value
        await changing.value
        await second.value
        #expect(order == ["first capture", "change", "second capture"])
    }

    @Test("Captures with no change between them run together")
    func capturesTogether() async {
        let firstCapture = HeldWork()
        var order: [String] = []
        let first = Task {
            await gate.capture {
                await firstCapture.hold()
                order.append("first capture")
            }
        }
        await settle { firstCapture.isHeld }
        await gate.capture {
            order.append("second capture")
        }
        #expect(order == ["second capture"])
        firstCapture.release()
        await first.value
        #expect(order == ["second capture", "first capture"])
    }

    @Test("A capture that throws lets the change that waits for it run")
    func failedCaptureFreesTheGate() async {
        struct Failure: Error {}
        let capture = HeldWork()
        let capturing = Task {
            try await gate.capture {
                await capture.hold()
                throw Failure()
            }
        }
        await settle { capture.isHeld }
        let changing = Task {
            await gate.run { "changed" }
        }
        await settleQueuedWork()
        capture.release()
        await #expect(throws: Failure.self) {
            try await capturing.value
        }
        #expect(await changing.value == "changed")
        #expect(gate.isChanging == false)
    }
}
