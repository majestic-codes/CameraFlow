//
//  FakeProvidedLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
@testable import CameraFlow

/// A location provider of an app, taken as it returns its location: for tests of what a photo does with a location,
/// whose fixed locations are older than the rule of `ProvidedPhotoLocation` lets through.
@MainActor
final class FakeProvidedLocation: PhotoLocationSource {
    private let provider: () -> CLLocation?

    init(_ provider: @escaping () -> CLLocation?) {
        self.provider = provider
    }

    func start() {}

    func stop() {}

    var location: CLLocation? {
        provider()
    }
}
