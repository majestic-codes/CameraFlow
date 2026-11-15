//
//  SimulatedAccess.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the user was asked before a flow over the simulated camera opens. It has no effect on the device camera.
///
/// Where the photo library or the location is "the system's", the flow uses the real one with its real requests.
/// Where it is simulated, it answers at once, with no system request, and a simulated location gives no fix.
@_spi(Testing)
public enum SimulatedAccess: Sendable, Hashable {
    /// The simulated camera is granted, and the photo library and the location are the system's.
    case granted
    /// The camera has not been asked for and is granted when it is. The photo library and the location are simulated
    /// and granted.
    case cameraNotAsked
    /// The camera has not been asked for and is refused when it is, as when the user says no. The photo library and
    /// the location are the system's.
    case cameraDenied
    /// Neither the camera nor the photo library has been asked for, and each is granted when it is. The photo
    /// library is simulated: it takes the photos and keeps none. The location is simulated and granted.
    case cameraAndPhotoLibraryNotAsked
    /// The camera is granted. The location has not been asked for and is granted when it is. The photo library is
    /// simulated and granted.
    case locationNotAsked
    /// The location has not been asked for and is refused when it is. The camera and the photo library are simulated
    /// and granted.
    case locationDenied
    /// None of the camera, the location and the photo library has been asked for, and each is granted when it is.
    /// The photo library is simulated: it takes the photos and keeps none.
    case cameraLocationAndPhotoLibraryNotAsked
    /// The camera is granted. The photo library has not been asked for and is granted when it is: it is simulated,
    /// takes the photos and keeps none. The location is simulated and granted.
    case photoLibraryNotAsked
    /// The camera is granted. Neither the location nor the photo library has been asked for, and each is granted
    /// when it is. Both are simulated, and the photo library takes the photos and keeps none.
    case locationAndPhotoLibraryNotAsked
}
