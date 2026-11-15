//
//  PhotoCaptureRequest.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation

/// A capture option the running camera refused.
enum PhotoCaptureOption: Sendable, Equatable {
    case flash(CameraFlowFlashMode)
    case livePhoto
    case format(CameraFlowPhotoFormat)
    case resolution
    /// Live Photo and Apple ProRAW together.
    case livePhotoWithRAW
}

/// One capture, checked against the capabilities.
struct PhotoCaptureRequest: Sendable, Equatable {
    let flashMode: CameraFlowFlashMode
    let isLivePhotoEnabled: Bool
    let format: CameraFlowPhotoFormat
    let resolution: PhotoCaptureResolution
    /// Where the photo is taken, written into the file as its GPS dictionary. Nil leaves the file without one.
    var location: CLLocation?
    /// Whether the Live Photo movie carries `location` too. The movie reaches the app as the camera wrote it, so it
    /// carries the location only where the app receives the metadata of its photos.
    var locatesLivePhotoMovie = false

    /// Checks the screen's settings against the camera and throws for the first one it cannot honour.
    init(
        flashMode: CameraFlowFlashMode,
        isLivePhotoEnabled: Bool,
        format: CameraFlowPhotoFormat,
        resolution: PhotoCaptureResolution,
        capabilities: PhotoCaptureCapabilities
    ) throws(CameraServiceError) {
        guard capabilities.flashModes.contains(flashMode) else {
            throw .unsupported(.flash(flashMode))
        }
        guard !isLivePhotoEnabled || capabilities.isLivePhotoSupported else {
            throw .unsupported(.livePhoto)
        }
        guard capabilities.formats.contains(format) else {
            throw .unsupported(.format(format))
        }
        guard capabilities.resolution == resolution else {
            throw .unsupported(.resolution)
        }
        guard format != .raw || !isLivePhotoEnabled else {
            throw .unsupported(.livePhotoWithRAW)
        }
        self.flashMode = flashMode
        self.isLivePhotoEnabled = isLivePhotoEnabled
        self.format = format
        self.resolution = resolution
    }
}
