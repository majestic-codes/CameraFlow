//
//  CameraChangeGate.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Lets one change of the camera run at a time, a start, a flip, a switch of the dual camera or a restart, and never
/// under a photo that is being taken.
///
/// What is asked for while a change runs waits for it, and runs after it in the order asked. A capture runs as soon
/// as no change runs or waits before it, beside the captures already running: a photo is taken by the camera that
/// runs once the changes asked for before it are over. A change waits for the captures that run, so the camera they
/// were taken with delivers their photos first.
@MainActor
final class CameraChangeGate {
    private enum Work {
        case change
        case capture
    }

    private struct Waiter {
        let work: Work
        let continuation: CheckedContinuation<Void, Never>
    }

    /// How many changes were asked for and are not over yet, the one that runs and the ones that wait.
    private var askedChangeCount = 0
    private var isChangeRunning = false
    private var runningCaptureCount = 0
    private var waiting: [Waiter] = []

    /// True from the moment a change is asked for until the last change asked for is over.
    var isChanging: Bool {
        askedChangeCount > 0
    }

    /// Runs the change once every change asked for before it and every capture that runs are over, and returns what
    /// it returns.
    @discardableResult
    func run<Result>(_ change: () async -> Result) async -> Result {
        askedChangeCount += 1
        if isChangeRunning || runningCaptureCount > 0 || !waiting.isEmpty {
            await withCheckedContinuation { waiting.append(Waiter(work: .change, continuation: $0)) }
        } else {
            isChangeRunning = true
        }
        let result = await change()
        isChangeRunning = false
        askedChangeCount -= 1
        admitWaiting()
        return result
    }

    /// Takes a photo once every change asked for before it is over. Changes asked for meanwhile wait until the photo
    /// is taken.
    func capture<Result>(_ take: () async throws -> Result) async rethrows -> Result {
        if isChangeRunning || !waiting.isEmpty {
            await withCheckedContinuation { waiting.append(Waiter(work: .capture, continuation: $0)) }
        } else {
            runningCaptureCount += 1
        }
        defer {
            runningCaptureCount -= 1
            admitWaiting()
        }
        return try await take()
    }

    /// Lets in what waits first: a change once nothing runs, or the captures up to the next change once no change
    /// runs.
    private func admitWaiting() {
        while let next = waiting.first {
            switch next.work {
            case .change:
                guard !isChangeRunning, runningCaptureCount == 0 else { return }
                isChangeRunning = true
                waiting.removeFirst()
                next.continuation.resume()
                return
            case .capture:
                guard !isChangeRunning else { return }
                runningCaptureCount += 1
                waiting.removeFirst()
                next.continuation.resume()
            }
        }
    }
}
