//
//  PhotoLocationPlan.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

/// Where the photos of a flow take their location and the direction of the camera from, and the location access
/// the flow asks through.
@MainActor
struct PhotoLocationPlan {
    /// Nil for photos without a location.
    let source: (any PhotoLocationSource)?
    /// Nil where the flow does not ask.
    let authorizer: (any LocationAuthorizer)?
    /// Where the photos take the direction of the camera from, nil for photos without one.
    let heading: (any PhotoHeadingSource)?

    /// The app's location provider, held to the rule of the flow's own location, or the flow's own location where
    /// the app passes none. The flow asks for access through its own location in either case, unless the app asks.
    /// The flow's own location is made only for photos that record a location, and the compass only for photos that
    /// record the direction: it follows the location where the photos record that too. Photos that cannot carry a
    /// location (`CameraFlowConfiguration.canCarryLocation`) get neither a location nor a direction, and nothing asks
    /// for access or follows the location.
    init(
        configuration: CameraFlowConfiguration,
        locationProvider: (() -> CLLocation?)?,
        makeProvidedLocation: (@escaping () -> CLLocation?) -> any PhotoLocationSource,
        makeSystemLocation: () -> any LocationAuthorizer & PhotoLocationSource,
        makeCompass: (_ followsLocation: Bool) -> any PhotoHeadingSource
    ) {
        guard configuration.canCarryLocation else {
            source = nil
            authorizer = nil
            heading = nil
            return
        }
        heading = switch configuration.photoDirection {
        case .off: nil
        case .recorded: makeCompass(configuration.photoLocation != .off)
        }
        guard configuration.photoLocation != .off else {
            source = nil
            authorizer = nil
            return
        }
        let system = makeSystemLocation()
        let photos: any PhotoLocationSource = locationProvider.map(makeProvidedLocation) ?? system
        source = photos
        authorizer = configuration.asksForLocation ? system : nil
    }
}
