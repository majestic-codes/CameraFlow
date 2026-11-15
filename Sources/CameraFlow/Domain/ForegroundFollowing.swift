//
//  ForegroundFollowing.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The rule a device service of the camera follows, such as the location, the compass or the motion sensors: it
/// runs while it is started and the app is in the foreground. It stops when the app goes to the background and runs
/// again when the app comes back, until it is stopped. The app's moves arrive as the two notifications of the
/// default center that it is made with.
@MainActor
final class ForegroundFollowing: NSObject {
    /// False from the app going to the background until it comes back.
    private(set) var isInForeground = true
    /// What the service does when it is told whether it runs, from `start(_:)` until `stop()`.
    private var follow: (@MainActor (_ isActive: Bool) -> Void)?

    /// Follows the app from now on: `background` is posted when it goes to the background, and `foreground` when it
    /// comes back.
    init(background: Notification.Name, foreground: Notification.Name) {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(appEnteredBackground), name: background, object: nil)
        center.addObserver(self, selector: #selector(appEnteredForeground), name: foreground, object: nil)
    }

    /// True while started and in the foreground, when the service runs.
    var isActive: Bool {
        follow != nil && isInForeground
    }

    /// Starts the service: `follow` hears at once whether it runs, and again whenever the app moves, until `stop()`.
    func start(_ follow: @escaping @MainActor (_ isActive: Bool) -> Void) {
        self.follow = follow
        follow(isInForeground)
    }

    /// Stops the service: it hears that it does not run, and then nothing more.
    func stop() {
        let follow = self.follow
        self.follow = nil
        follow?(false)
    }

    @objc private func appEnteredBackground() {
        isInForeground = false
        follow?(false)
    }

    @objc private func appEnteredForeground() {
        isInForeground = true
        follow?(true)
    }
}
