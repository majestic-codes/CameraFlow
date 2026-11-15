//
//  ProvidedPhotoLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

/// The location the app's `locationProvider` returns, held to the rule of the flow's own location
/// (`PhotoLocationFix`): a photo records it while it is valid and recent enough for the precision of the app's
/// location access. The app follows the location itself.
@MainActor
final class ProvidedPhotoLocation: PhotoLocationSource {
    private let provider: () -> CLLocation?
    /// The precision of the app's location access, read at every photo, as the user may switch Precise Location
    /// while the camera runs.
    private let precision: () -> LocationPrecision

    init(_ provider: @escaping () -> CLLocation?, precision: @escaping () -> LocationPrecision) {
        self.provider = provider
        self.precision = precision
    }

    func start() {}

    func stop() {}

    var location: CLLocation? {
        PhotoLocationFix.recent(provider(), at: .now, precision: precision())
    }
}

#if os(iOS)
extension ProvidedPhotoLocation {
    /// The app's location provider, with the precision of the app's location access as Core Location tells it.
    convenience init(_ provider: @escaping () -> CLLocation?) {
        let manager = CLLocationManager()
        self.init(provider) {
            LocationPrecision(manager.accuracyAuthorization)
        }
    }
}
#endif
