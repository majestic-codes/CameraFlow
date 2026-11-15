//
//  LocationAccessRequests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The requests for when-in-use location access that wait for the user's answer.
///
/// The system is asked while a request waits and the app is in the foreground: once for the requests that wait
/// together, and again each time the app comes back, as Core Location ignores a request of an app that is not in
/// use. A request whose task is cancelled returns the standing answer at once, and the others wait on.
@MainActor
final class LocationAccessRequests {
    private var waiters: [UUID: CheckedContinuation<LocationAuthorization, Never>] = [:]
    /// Asks the system while a request waits and the app is in the foreground.
    private let foreground: ForegroundFollowing
    /// The answer that stands now.
    private let standing: () -> LocationAuthorization
    /// Brings up the system's request.
    private let ask: () -> Void

    init(
        foreground: ForegroundFollowing,
        standing: @escaping () -> LocationAuthorization,
        ask: @escaping () -> Void
    ) {
        self.foreground = foreground
        self.standing = standing
        self.ask = ask
    }

    /// Waits for the user's answer. Returns the standing answer at once when the calling task is cancelled.
    func waitForAnswer() async -> LocationAuthorization {
        let identifier = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard Task.isCancelled == false else {
                    continuation.resume(returning: standing())
                    return
                }
                wait(continuation, as: identifier)
            }
        } onCancel: {
            Task { @MainActor in
                self.cancel(identifier)
            }
        }
    }

    /// Hands the user's answer to every request that waits.
    func answer(with authorization: LocationAuthorization) {
        let waiting = waiters.values
        waiters = [:]
        foreground.stop()
        waiting.forEach { $0.resume(returning: authorization) }
    }

    /// Keeps the request until the answer. The first of the requests that wait together starts asking the system.
    private func wait(_ continuation: CheckedContinuation<LocationAuthorization, Never>, as identifier: UUID) {
        let isFirst = waiters.isEmpty
        waiters[identifier] = continuation
        guard isFirst else { return }
        foreground.start { [weak self] isActive in
            guard isActive else { return }
            self?.ask()
        }
    }

    /// Returns the standing answer to a request whose task was cancelled before the answer came.
    private func cancel(_ identifier: UUID) {
        guard let continuation = waiters.removeValue(forKey: identifier) else { return }
        if waiters.isEmpty {
            foreground.stop()
        }
        continuation.resume(returning: standing())
    }
}
