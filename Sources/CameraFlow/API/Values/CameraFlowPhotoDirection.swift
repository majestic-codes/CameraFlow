//
//  CameraFlowPhotoDirection.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Whether the photos the camera takes record the direction the camera pointed in.
///
/// The direction comes from the compass of Core Location (`CLHeading`) at the shutter release, and goes into the GPS
/// dictionary of the file as `GPSImgDirection`, in degrees clockwise from north, also as `GPSDestBearing`, with the
/// reference "T" for the true north where Core Location knows it and "M" for the magnetic north otherwise. Core
/// Location knows the true north from the location, which the compass follows only where the photos record their
/// location (not ``CameraFlowPhotoLocation/off``) and the user granted location access. It is the direction the back of
/// the phone faces, in every way the phone is held, and not the direction the phone moved in: that is
/// `CLLocation.course`, which a photo with a location records apart as `GPSTrack`.
///
/// A reading is recorded only when it is valid, at most 45 degrees off and at most 5 seconds old, and every sample of
/// the compass counts, so a phone held still on a tripod or under the self-timer records its direction. Without a
/// reading the photo is taken and handed over without a direction: the shutter never waits for the compass, and the
/// flow never shows the calibration screen of the compass. A device without a compass records none.
///
/// The direction goes with the location: the files that carry the GPS dictionary carry it (see ``CameraFlowPhoto``),
/// which leaves out a RAW photo and a photo whose metadata the output strips. A photo without a location records the
/// direction alone. A photo saved to the system photo library has it in its file, and Photos shows no direction of its
/// own. The flow asks for no access for it: the location keeps its own modes (``CameraFlowPhotoLocation``). A flow
/// whose photos cannot carry a location, because its output strips the metadata and it never saves to the photo
/// library, treats the direction and ``CameraFlowConfiguration/photoLocation`` as off: it records no direction and does
/// not run the compass.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowPhotoDirection: Sendable, Hashable {
    /// The photos record no direction. The default.
    case off
    /// The photos record the direction of the camera when the compass gives a good reading.
    case recorded
}
