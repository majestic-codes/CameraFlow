//
//  SimulatedAccess+Composition.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What a flow over the simulated camera opens with under each access: the camera's answers, and the photo library
/// and the location beside it.
extension SimulatedAccess {
    /// The photo library of a flow over the simulated camera.
    enum PhotoLibrary: Sendable, Equatable {
        /// The system's, with its real requests.
        case system
        /// One with no Photos behind it, granted before the flow opens or granted when it is asked.
        case simulated(isAuthorizationDetermined: Bool)
    }

    /// The location of a flow over the simulated camera.
    enum Location: Sendable, Equatable {
        /// Core Location's, with its real requests.
        case system
        /// One with no Core Location behind it and no fix: the answer it stands at, and the answer a request gives
        /// while it is undecided.
        case simulated(authorization: LocationAuthorization, answerOnRequest: LocationAuthorization)
    }

    /// Whether the simulated camera was granted before the flow opens.
    var grantsCameraBefore: Bool {
        switch self {
        case .granted, .locationNotAsked, .locationDenied, .photoLibraryNotAsked, .locationAndPhotoLibraryNotAsked: true
        case .cameraNotAsked, .cameraDenied, .cameraAndPhotoLibraryNotAsked, .cameraLocationAndPhotoLibraryNotAsked:
            false
        }
    }

    /// The answer the simulated camera gives when it is asked for.
    var cameraAnswer: CameraAuthorization {
        self == .cameraDenied ? .denied : .authorized
    }

    var photoLibrary: PhotoLibrary {
        switch self {
        case .granted, .cameraDenied:
            .system
        case .cameraNotAsked, .locationNotAsked, .locationDenied:
            .simulated(isAuthorizationDetermined: true)
        case .cameraAndPhotoLibraryNotAsked, .cameraLocationAndPhotoLibraryNotAsked, .photoLibraryNotAsked,
            .locationAndPhotoLibraryNotAsked:
            .simulated(isAuthorizationDetermined: false)
        }
    }

    var location: Location {
        switch self {
        case .granted, .cameraDenied:
            .system
        case .cameraNotAsked, .cameraAndPhotoLibraryNotAsked, .photoLibraryNotAsked:
            .simulated(authorization: .authorized, answerOnRequest: .authorized)
        case .locationNotAsked, .cameraLocationAndPhotoLibraryNotAsked, .locationAndPhotoLibraryNotAsked:
            .simulated(authorization: .notDetermined, answerOnRequest: .authorized)
        case .locationDenied:
            .simulated(authorization: .notDetermined, answerOnRequest: .denied)
        }
    }
}
