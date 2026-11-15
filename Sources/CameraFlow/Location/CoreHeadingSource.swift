//
//  CoreHeadingSource.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation
import os
import UIKit

/// The direction of the camera from the compass of Core Location, followed while the camera runs and the app is in
/// the foreground. It never asks for location access: the compass gives the magnetic heading without it. Core
/// Location gives the true heading only to a manager that follows the location too, so where the photos record
/// their location and the user granted access, the compass also follows the location, to a kilometre.
@MainActor
final class CoreHeadingSource: NSObject, PhotoHeadingSource, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let following = ForegroundFollowing(
        background: UIApplication.didEnterBackgroundNotification,
        foreground: UIApplication.willEnterForegroundNotification
    )
    /// Whether the photos record their location, so that the compass may follow it for the true north.
    private let followsLocation: Bool
    private var reading: CompassReading?

    nonisolated private static let logger = Logger.camera("CoreHeadingSource")

    init(followsLocation: Bool) {
        self.followsLocation = followsLocation
        super.init()
        // Every sample of the compass is reported, also while the phone is held still.
        manager.headingFilter = kCLHeadingFilterNone
        manager.headingOrientation = .portrait
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = self
    }

    func start() {
        following.start { [weak self] isActive in
            self?.follow(isActive)
        }
    }

    func stop() {
        following.stop()
    }

    func deviceOrientationChanged(to orientation: CameraOrientation) {
        manager.headingOrientation = switch orientation {
        case .portrait: .portrait
        case .landscapeLeft: .landscapeLeft
        case .landscapeRight: .landscapeRight
        case .upsideDown: .portraitUpsideDown
        }
    }

    var heading: PhotoHeading? {
        PhotoHeadingFix.heading(of: reading, at: .now)
    }

    /// Runs what the compass needs while it is active, and stops it and forgets the reading otherwise.
    private func follow(_ isActive: Bool) {
        let updates = CompassUpdates(
            isActive: isActive,
            hasCompass: CLLocationManager.headingAvailable(),
            followsLocation: followsLocation,
            authorization: LocationAuthorization(manager.authorizationStatus)
        )
        if updates.heading {
            manager.startUpdatingHeading()
        } else {
            manager.stopUpdatingHeading()
            reading = nil
        }
        if updates.location {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // The manager calls its delegate on the thread it was created on, the main thread here.
        MainActor.assumeIsolated {
            follow(following.isActive)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let reading = CompassReading(
            trueHeading: newHeading.trueHeading,
            magneticHeading: newHeading.magneticHeading,
            accuracy: newHeading.headingAccuracy,
            timestamp: newHeading.timestamp
        )
        // The manager calls its delegate on the thread it was created on, the main thread here.
        MainActor.assumeIsolated {
            self.reading = reading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Self.logger.info("No heading, or no location for it: \(String(describing: error), privacy: .public)")
        guard CompassReading.isEnded(by: error) else { return }
        // The manager calls its delegate on the thread it was created on, the main thread here.
        MainActor.assumeIsolated {
            reading = nil
        }
    }

    /// The compass is not calibrated on the screen: a photo taken meanwhile simply records no direction, or the
    /// reading it has while it is still accurate enough.
    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        false
    }
}
#endif
