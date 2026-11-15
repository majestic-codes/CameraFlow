//
//  CameraPictureCover.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What shows a camera's picture on screen and can hold a still of it over the live one, so that a change of the
/// camera behind it is never seen half done.
@MainActor
protocol CameraPictureCover: AnyObject {

    /// Covers the live picture with a still of what the screen shows now. The still stays until `uncoverPicture()`.
    func coverPicture()
    /// Lets the still go, so the live picture shows again. Nothing happens when the picture is not covered.
    func uncoverPicture()
}
