//
//  SimulatedLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

/// Location access with no Core Location behind it, for a flow over the simulated camera: it answers at once with
/// the answer it was given, and knows no location.
@MainActor
final class SimulatedLocation: LocationAuthorizer, PhotoLocationSource {
    private(set) var authorization: LocationAuthorization
    private let answerOnRequest: LocationAuthorization

    init(authorization: LocationAuthorization, answerOnRequest: LocationAuthorization = .authorized) {
        self.authorization = authorization
        self.answerOnRequest = answerOnRequest
    }

    func requestAuthorization() async -> LocationAuthorization {
        if authorization == .notDetermined {
            authorization = answerOnRequest
        }
        return authorization
    }

    func start() {}

    func stop() {}

    var location: CLLocation? {
        nil
    }
}
