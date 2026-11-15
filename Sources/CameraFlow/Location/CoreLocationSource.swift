//
//  CoreLocationSource.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation
import os
import UIKit

/// The location of this phone from Core Location: when-in-use access, and the location followed at the best
/// accuracy while the camera runs and the app is in the foreground, as a camera does. With approximate access the
/// location is the approximate one, which counts for longer because Core Location updates it rarely.
@MainActor
final class CoreLocationSource: NSObject, LocationAuthorizer, PhotoLocationSource, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private let following: ForegroundFollowing
    /// The requests waiting for the user's answer.
    private let requests: LocationAccessRequests

    private static let usageDescriptionKey = "NSLocationWhenInUseUsageDescription"
    nonisolated private static let logger = Logger.camera("CoreLocationSource")

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        following = Self.followingTheApp()
        requests = LocationAccessRequests(
            foreground: Self.followingTheApp(),
            standing: { LocationAuthorization(manager.authorizationStatus) },
            ask: { manager.requestWhenInUseAuthorization() }
        )
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
    }

    /// Follows the app's moves between the foreground and the background.
    private static func followingTheApp() -> ForegroundFollowing {
        ForegroundFollowing(
            background: UIApplication.didEnterBackgroundNotification,
            foreground: UIApplication.willEnterForegroundNotification
        )
    }

    var authorization: LocationAuthorization {
        LocationAuthorization(manager.authorizationStatus)
    }

    /// An app without the usage description gets no request from the system, so the answer stays undetermined and
    /// comes at once. A request made while the app is not in use is asked again when the app comes back.
    func requestAuthorization() async -> LocationAuthorization {
        let standing = authorization
        guard standing == .notDetermined else { return standing }
        guard Bundle.main.object(forInfoDictionaryKey: Self.usageDescriptionKey) != nil else {
            let key = Self.usageDescriptionKey
            Self.logger.error("No \(key, privacy: .public) in Info.plist: the location is not asked for")
            return standing
        }
        return await requests.waitForAnswer()
    }

    func start() {
        following.start { [weak self] isActive in
            self?.follow(isActive)
        }
    }

    func stop() {
        following.stop()
    }

    /// The precision is read at every photo, as the user may switch Precise Location while the camera runs.
    var location: CLLocation? {
        let precision = LocationPrecision(manager.accuracyAuthorization)
        return PhotoLocationFix.recent(manager.location, at: .now, precision: precision)
    }

    /// Follows the location while started, in the foreground and with access, and stops otherwise.
    private func follow(_ isActive: Bool) {
        if isActive, authorization == .authorized {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // The manager calls its delegate on the thread it was created on, the main thread here.
        MainActor.assumeIsolated {
            authorizationChanged()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Self.logger.info("No location: \(String(describing: error), privacy: .public)")
    }

    private func authorizationChanged() {
        follow(following.isActive)
        let answer = authorization
        guard answer != .notDetermined else { return }
        requests.answer(with: answer)
    }
}
#endif
