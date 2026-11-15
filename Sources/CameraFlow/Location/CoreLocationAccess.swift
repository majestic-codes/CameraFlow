//
//  CoreLocationAccess.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

extension LocationAuthorization {
    /// The access an authorization status of Core Location stands for. A status newer than this code is taken as
    /// no access.
    init(_ status: CLAuthorizationStatus) {
        self = switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .denied
        }
    }
}

extension LocationPrecision {
    /// The precision of the access the user granted. An accuracy newer than this code is taken as approximate, the
    /// precision whose location comes rarely.
    init(_ accuracy: CLAccuracyAuthorization) {
        self = switch accuracy {
        case .fullAccuracy: .precise
        case .reducedAccuracy: .approximate
        @unknown default: .approximate
        }
    }
}
