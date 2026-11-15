//
//  CallGate.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Holds the calls that reach it until the test opens it, counts them, and tells the test when the first one has
/// arrived.
actor CallGate {
    private(set) var arrivalCount = 0
    private var isOpen = false
    private var heldCalls: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []

    func pass() async {
        arrivalCount += 1
        arrivalWaiters.forEach { $0.resume() }
        arrivalWaiters = []
        guard !isOpen else { return }
        await withCheckedContinuation { heldCalls.append($0) }
    }

    /// Returns once a call is held at the gate, or has passed it.
    func arrival() async {
        guard arrivalCount == 0 else { return }
        await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func open() {
        isOpen = true
        heldCalls.forEach { $0.resume() }
        heldCalls = []
    }
}
