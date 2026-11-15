//
//  CameraSettings.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// A camera setting with a tile in the control panel and a sub-panel of its own. Opens a sub-panel through
/// `CameraFlowInitialState.panel`. The settings a user may change are the ones the app made adjustable.
@_spi(Testing)
public enum CameraSetting: String, Sendable, Hashable, CaseIterable {
    /// Flash mode.
    case flash
    /// Live Photo.
    case live
    /// Aspect ratio of the photo.
    case aspect
    /// Self timer.
    case timer
    /// Exposure bias.
    case exposure
    /// File format and the quality of the photos.
    case format
    /// The second camera in a circle of the viewfinder, where the device can run two cameras.
    case dualCamera
    /// Saving to the system photo library.
    case librarySave
}

/// Flash behaviour for the next photo. The raw values are what the flow remembers and the app stores.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowFlashMode: String, Sendable, Hashable, CaseIterable, Codable {
    /// The camera fires the flash when the scene is dark enough for it.
    case auto
    /// The flash always fires.
    case alwaysOn = "on"
    /// The flash never fires.
    case off
}

/// Aspect ratio of the viewfinder and of the photo. The raw values are what the flow remembers and the app stores.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowAspectRatio: String, Sendable, Hashable, CaseIterable, Codable {
    /// The sensor's own 4:3.
    case fourByThree = "4:3"
    /// 16:9.
    case sixteenByNine = "16:9"
    /// A square.
    case square = "1:1"

    /// Height of the frame for a width of one.
    var heightPerWidth: CGFloat {
        switch self {
        case .fourByThree: 4.0 / 3.0
        case .sixteenByNine: 16.0 / 9.0
        case .square: 1
        }
    }
}

/// Delay between the shutter tap and the photo. The raw values, in seconds, are what the flow remembers and the app
/// stores.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowTimer: Int, Sendable, Hashable, CaseIterable, Codable {
    /// No delay.
    case off = 0
    /// Three seconds.
    case threeSeconds = 3
    /// Five seconds.
    case fiveSeconds = 5
    /// Ten seconds.
    case tenSeconds = 10
}

/// File format of the photo, as the format row of the camera's Format panel offers it. The raw values are what the
/// flow remembers and the app stores.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`. A choice of resolution, such as the 24 MP or 48 MP of a Pro camera, would be a setting of its
/// own.
public enum CameraFlowPhotoFormat: String, Sendable, Hashable, CaseIterable, Codable {
    /// HEIF, the name the stock Format panel shows: the file is a HEIC (`UTType.heic`), or a JPEG on a camera that
    /// cannot encode HEVC.
    case heif = "HEIF"
    /// Apple ProRAW, as a DNG. Not available with Live Photo.
    case raw = "RAW"
}

/// What the control panel shows.
@_spi(Testing)
public enum CameraPanelPresentation: Sendable, Hashable {
    /// The panel is closed.
    case hidden
    /// The grid of setting tiles.
    case tiles
    /// The sub-panel of one setting.
    case subPanel(CameraSetting)
}
