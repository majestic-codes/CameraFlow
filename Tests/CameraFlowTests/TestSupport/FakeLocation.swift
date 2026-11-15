//
//  FakeLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
@testable import CameraFlow

/// Location access and a location that record what is asked of them. A decided access returns its standing answer
/// at once, as Core Location does. An undecided one is answered as the test set it, at once or, with
/// `holdsRequest`, once the test releases it, as the system's request waits for the user. A held request whose
/// task is cancelled returns the standing answer at once.
@MainActor
final class FakeLocation: LocationAuthorizer, PhotoLocationSource {
    private(set) var authorization: LocationAuthorization
    /// The answer a request gives where the user has not answered yet.
    var answerOnRequest: LocationAuthorization
    var holdsRequest = false
    /// How many times access was asked for.
    private(set) var requestCount = 0
    /// `start` and `stop` in the order they came.
    private(set) var followCalls: [Bool] = []
    /// What `location` returns.
    var currentLocation: CLLocation?
    /// The held requests, each resumed with true when the test releases it and false when its task is cancelled.
    private var heldRequests: [UUID: CheckedContinuation<Bool, Never>] = [:]

    init(authorization: LocationAuthorization = .notDetermined, answerOnRequest: LocationAuthorization = .authorized) {
        self.authorization = authorization
        self.answerOnRequest = answerOnRequest
    }

    var heldRequestCount: Int {
        heldRequests.count
    }

    func requestAuthorization() async -> LocationAuthorization {
        requestCount += 1
        guard authorization == .notDetermined else { return authorization }
        if holdsRequest {
            let isReleased = await hold()
            guard isReleased else { return authorization }
        }
        if authorization == .notDetermined {
            authorization = answerOnRequest
        }
        return authorization
    }

    func releaseHeldRequests() {
        let held = heldRequests.values
        heldRequests = [:]
        held.forEach { $0.resume(returning: true) }
    }

    /// Waits until the test releases the request, true then, or until its task is cancelled, false then.
    private func hold() async -> Bool {
        let identifier = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard Task.isCancelled == false else {
                    continuation.resume(returning: false)
                    return
                }
                heldRequests[identifier] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelHeldRequest(identifier)
            }
        }
    }

    private func cancelHeldRequest(_ identifier: UUID) {
        heldRequests.removeValue(forKey: identifier)?.resume(returning: false)
    }

    func start() {
        followCalls.append(true)
    }

    func stop() {
        followCalls.append(false)
    }

    var location: CLLocation? {
        currentLocation
    }
}
