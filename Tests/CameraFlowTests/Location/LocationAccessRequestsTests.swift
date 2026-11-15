//
//  LocationAccessRequestsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The requests for location access as Core Location's source makes them: asked in the foreground, again when the
/// app comes back, and given up by a cancelled task. The app's moves are notifications of names no other test posts.
@MainActor
@Suite("Requests for location access wait for the user's answer", .timeLimit(.minutes(1)))
struct LocationAccessRequestsTests {
    private let background = Notification.Name("LocationAccessRequestsTests.background.\(UUID())")
    private let foreground = Notification.Name("LocationAccessRequestsTests.foreground.\(UUID())")

    /// The system as the requests see it: the answer that stands, and how many times it was asked.
    @MainActor
    private final class System {
        var standing = LocationAuthorization.notDetermined
        var askCount = 0
    }

    private func makeRequests(system: System) -> LocationAccessRequests {
        LocationAccessRequests(
            foreground: ForegroundFollowing(background: background, foreground: foreground),
            standing: { system.standing },
            ask: { system.askCount += 1 }
        )
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    @Test("Requests that wait together ask the system once and all get the user's answer")
    func answered() async {
        let system = System()
        let requests = makeRequests(system: system)
        let first = Task { await requests.waitForAnswer() }
        let second = Task { await requests.waitForAnswer() }
        await settle { system.askCount == 1 }
        await settleQueuedWork()
        requests.answer(with: .authorized)
        #expect(await first.value == .authorized)
        #expect(await second.value == .authorized)
        #expect(system.askCount == 1)
    }

    @Test("A cancelled request returns the standing answer at once, and the others wait on")
    func cancelled() async {
        let system = System()
        let requests = makeRequests(system: system)
        let cancelled = Task { await requests.waitForAnswer() }
        let waiting = Task { await requests.waitForAnswer() }
        await settle { system.askCount == 1 }
        await settleQueuedWork()
        cancelled.cancel()
        #expect(await cancelled.value == .notDetermined)
        requests.answer(with: .denied)
        #expect(await waiting.value == .denied)
        #expect(system.askCount == 1)
    }

    @Test("A request of a task cancelled before it asks returns the standing answer without asking")
    func cancelledBeforeAsking() async {
        let system = System()
        system.standing = .denied
        let requests = makeRequests(system: system)
        let request = Task { await requests.waitForAnswer() }
        request.cancel()
        #expect(await request.value == .denied)
        #expect(system.askCount == 0)
    }

    @Test("The system is asked again each time the app comes back before the answer, and no more after it")
    func askedAgainInTheForeground() async {
        let system = System()
        let requests = makeRequests(system: system)
        let request = Task { await requests.waitForAnswer() }
        await settle { system.askCount == 1 }
        post(background)
        #expect(system.askCount == 1)
        post(foreground)
        #expect(system.askCount == 2)
        requests.answer(with: .authorized)
        #expect(await request.value == .authorized)
        post(background)
        post(foreground)
        #expect(system.askCount == 2)
    }

    @Test("A request made in the background is asked once the app comes back")
    func madeInTheBackground() async {
        let system = System()
        let requests = makeRequests(system: system)
        post(background)
        let request = Task { await requests.waitForAnswer() }
        await settleQueuedWork()
        #expect(system.askCount == 0)
        post(foreground)
        #expect(system.askCount == 1)
        requests.answer(with: .authorized)
        #expect(await request.value == .authorized)
    }

    @Test("Once the last request is cancelled the app's return asks nothing")
    func lastCancelled() async {
        let system = System()
        let requests = makeRequests(system: system)
        let request = Task { await requests.waitForAnswer() }
        await settle { system.askCount == 1 }
        request.cancel()
        #expect(await request.value == .notDetermined)
        post(background)
        post(foreground)
        #expect(system.askCount == 1)
    }
}
