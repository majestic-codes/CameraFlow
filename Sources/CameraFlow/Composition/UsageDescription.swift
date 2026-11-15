//
//  UsageDescription.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// A usage description of the app's Info.plist that a system resource of the flow needs. The system terminates an
/// app that asks for the camera or the photo library without one, possibly after a whole set was taken, and ignores
/// a request for the location. So the flow checks the descriptions of the resources it will ask for when it is
/// assembled, and stops with the key's name instead.
enum UsageDescription: String, CaseIterable {
    case camera = "NSCameraUsageDescription"
    /// For saving to the library itself, with add-only access.
    case photoLibraryAdd = "NSPhotoLibraryAddUsageDescription"
    /// For saving into an album, with read-write access.
    case photoLibrary = "NSPhotoLibraryUsageDescription"
    case locationWhenInUse = "NSLocationWhenInUseUsageDescription"

    /// The description that saving to a destination of the photo library asks with.
    static func photoLibrary(for destination: CameraFlowPhotoLibrarySaving.Destination) -> Self {
        switch destination {
        case .library: .photoLibraryAdd
        case .album: .photoLibrary
        }
    }

    /// Stops the program when the Info.plist read through `infoValue` lacks the description.
    func require(in infoValue: (String) -> Any?) {
        precondition(infoValue(rawValue) != nil, missingMessage)
    }

    /// What the program says when it stops on the missing description: what asks with it, the key and the way out.
    var missingMessage: String {
        let saving = "Add it, or set configuration.photoLibrarySaving.isEnabled to .fixed(false)."
        return switch self {
        case .camera:
            "CameraFlow: the camera of the device needs \(rawValue) in the app's Info.plist."
        case .photoLibraryAdd:
            "CameraFlow: saving to the photo library needs \(rawValue) in the app's Info.plist. \(saving)"
        case .photoLibrary:
            "CameraFlow: saving into an album needs \(rawValue) in the app's Info.plist. \(saving)"
        case .locationWhenInUse:
            "CameraFlow: configuration.photoLocation .automatic asks for the location, which needs \(rawValue) in"
                + " the app's Info.plist. Add it, or set photoLocation to .appRequestsAccess or .off."
        }
    }
}
