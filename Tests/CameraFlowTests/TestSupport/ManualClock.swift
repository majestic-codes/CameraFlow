//
//  ManualClock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os
import Testing

/// A clock that moves only when a test advances it. Sleepers wake when the time reaches their deadline.
final class ManualClock: Clock, Sendable {
    struct Instant: InstantProtocol {
        let offset: Duration

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }

        static func < (left: Self, right: Self) -> Bool {
            left.offset < right.offset
        }
    }

    private struct Sleeper {
        let identifier: Int
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var nextIdentifier = 0
        var sleepers: [Sleeper] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var now: Instant {
        state.withLock(\.now)
    }

    var sleeperCount: Int {
        state.withLock(\.sleepers.count)
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let identifier = state.withLock { state in
            state.nextIdentifier += 1
            return state.nextIdentifier
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let sleeper = Sleeper(identifier: identifier, deadline: deadline, continuation: continuation)
                let woken = state.withLock { state in
                    if Task.isCancelled {
                        return [WakeUp.cancel(continuation)]
                    }
                    if deadline <= state.now {
                        return [WakeUp.resume(continuation)]
                    }
                    state.sleepers.append(sleeper)
                    return []
                }
                woken.forEach { $0.perform() }
            }
        } onCancel: {
            let cancelled = state.withLock { state in
                let index = state.sleepers.firstIndex { $0.identifier == identifier }
                return index.map { state.sleepers.remove(at: $0) }
            }
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the time forward and wakes every sleeper whose deadline it reaches.
    func advance(by duration: Duration) {
        let woken = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let due = state.sleepers.filter { $0.deadline <= now }
            state.sleepers.removeAll { $0.deadline <= now }
            return due
        }
        woken.forEach { $0.continuation.resume() }
    }

    /// Returns once at least `count` sleepers wait on the clock. Fails after `TestWait.limit` instead of waiting
    /// forever for a sleeper that never comes.
    func waitForSleepers(count: Int = 1, sourceLocation: SourceLocation = #_sourceLocation) async {
        let hasSleepers = await TestWait.poll { self.sleeperCount >= count }
        if !hasSleepers {
            Issue.record(
                "\(sleeperCount) of \(count) sleepers wait on the clock after \(TestWait.limit)",
                sourceLocation: sourceLocation
            )
        }
    }

    private enum WakeUp {
        case resume(CheckedContinuation<Void, any Error>)
        case cancel(CheckedContinuation<Void, any Error>)

        func perform() {
            switch self {
            case let .resume(continuation): continuation.resume()
            case let .cancel(continuation): continuation.resume(throwing: CancellationError())
            }
        }
    }
}

/// The bound of every wait of a test on work that is under way. It is real time, far beyond what the work takes, so
/// a loaded machine does not run into it and broken code fails the test instead of hanging it.
enum TestWait {
    static let limit: Duration = .seconds(30)

    /// Lets the work that is under way run until the condition holds, and says whether it came to hold in time.
    static func poll(
        isolation: isolated (any Actor)? = #isolation,
        until condition: () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: limit)
        while !condition() {
            guard ContinuousClock.now < deadline else { return false }
            await Task.yield()
        }
        return true
    }
}

/// Lets the main actor run the work that is under way until the condition holds. Fails after `TestWait.limit`
/// instead of waiting forever.
@MainActor
func settle(
    until condition: () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    if await !TestWait.poll(until: condition) {
        Issue.record("The condition did not hold after \(TestWait.limit)", sourceLocation: sourceLocation)
    }
}

/// Gives the work that is already queued on the main actor its turns, before an expectation that something has not
/// happened: there is no condition to wait for, so the wait is a fixed number of turns.
@MainActor
func settleQueuedWork() async {
    for _ in 0..<100 {
        await Task.yield()
    }
}
