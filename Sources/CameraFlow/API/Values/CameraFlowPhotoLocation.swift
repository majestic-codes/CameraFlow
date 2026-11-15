//
//  CameraFlowPhotoLocation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Whether the photos the camera takes record where they were taken, as the stock Camera's do, and who asks the
/// user for location access.
///
/// A photo with a location carries it as the GPS dictionary of its file and, saved to the photo library, as the
/// location of the asset. The location comes from the flow itself, which follows it with Core Location while the
/// camera is on screen, or from the `locationProvider` the app passes to ``CameraFlowView`` or
/// ``CameraFlowViewController``, which then replaces the flow's own. A location of the app's counts as the flow's own
/// does, while it is valid and at most 60 seconds old, or 20 minutes for an approximate one. With Precise Location
/// off, a photo records the approximate location. A location goes with its accuracy, as `GPSHPositioningError`.
///
/// The flow asks for when-in-use access only, and only while the user has not answered: in its introduction
/// (``CameraFlowOnboarding/automatic``), on a step after the camera's, or right after the camera is granted where the
/// introduction is off. Both need `NSLocationWhenInUseUsageDescription` in the app's Info.plist: a flow that would
/// ask without it stops the program when it starts. A photo is taken without a location when access is not granted
/// or no recent location is known: the shutter never waits for one.
///
/// A flow whose photos cannot carry a location, because its output strips the metadata and it never saves to the photo
/// library, treats the location and ``CameraFlowConfiguration/photoDirection`` as off: it never asks for access,
/// follows neither the location nor the compass and calls no `locationProvider`.
///
/// This governs the photos the camera takes. A photo picked from the library keeps the location of its file, where the
/// system picker hands one over, whatever this says: only an output that strips the metadata
/// (``CameraFlowOutputMetadata/stripped``) takes it out. So an app that uploads the photos it receives may handle a
/// precise location even under ``off``.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowPhotoLocation: Sendable, Hashable {
    /// The photos record their location, and the flow asks for access when the user has not answered yet.
    case automatic
    /// The photos record their location while the app has access, and the flow never asks: the app does, before it
    /// opens the flow.
    case appRequestsAccess
    /// The photos the camera takes record no location and the flow never asks. A photo picked from the library keeps
    /// the location of its file, where the system picker hands one over. A flow created with a `locationProvider` and
    /// this stops the program.
    case off
}

extension CameraFlowConfiguration {
    /// Whether the flow asks the user for location access when the user has not answered yet.
    var asksForLocation: Bool {
        photoLocation == .automatic
    }

    /// Stops the program on a location provider for photos that record no location.
    func validate(hasLocationProvider: Bool) {
        validate()
        precondition(
            !hasLocationProvider || photoLocation != .off,
            "CameraFlow: a locationProvider is passed while configuration.photoLocation is .off"
        )
    }
}
