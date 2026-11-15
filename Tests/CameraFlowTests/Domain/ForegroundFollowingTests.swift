//
//  ForegroundFollowingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The rule of the location, the compass and the motion sensors: they run while started and in the foreground. The
/// app's moves are notifications of names no other test posts.
@MainActor
@Suite("A device service runs while started and in the foreground")
struct ForegroundFollowingTests {
    private let background = Notification.Name("ForegroundFollowingTests.background.\(UUID())")
    private let foreground = Notification.Name("ForegroundFollowingTests.foreground.\(UUID())")

    private func makeFollowing() -> ForegroundFollowing {
        ForegroundFollowing(background: background, foreground: foreground)
    }

    private func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }

    @Test("A started service runs, stops in the background, runs again in the foreground and stops when stopped")
    func followsTheApp() {
        let following = makeFollowing()
        var runs: [Bool] = []
        following.start { runs.append($0) }
        #expect(following.isActive)
        post(background)
        #expect(following.isActive == false)
        post(foreground)
        #expect(following.isActive)
        following.stop()
        #expect(following.isActive == false)
        #expect(runs == [true, false, true, false])
    }

    @Test("A service started in the background runs once the app comes back")
    func startedInTheBackground() {
        let following = makeFollowing()
        var runs: [Bool] = []
        post(background)
        following.start { runs.append($0) }
        #expect(following.isActive == false)
        post(foreground)
        #expect(following.isActive)
        #expect(runs == [false, true])
    }

    @Test("A stopped service hears nothing of the app's moves")
    func stopped() {
        let following = makeFollowing()
        var runs: [Bool] = []
        following.start { runs.append($0) }
        post(background)
        following.stop()
        post(foreground)
        post(background)
        #expect(following.isActive == false)
        #expect(runs == [true, false, false])
    }

    @Test("Stopping a service that never started tells nothing")
    func neverStarted() {
        let following = makeFollowing()
        following.stop()
        post(background)
        post(foreground)
        #expect(following.isActive == false)
        #expect(following.isInForeground)
    }
}
