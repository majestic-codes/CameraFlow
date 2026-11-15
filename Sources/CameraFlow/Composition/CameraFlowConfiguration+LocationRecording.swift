//
//  CameraFlowConfiguration+LocationRecording.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

extension CameraFlowConfiguration {
    /// Whether a photo of the flow can carry a location and a direction: the files the app receives keep their
    /// metadata, or the camera's own file may go to the photo library. A flow whose photos cannot carry them treats
    /// `photoLocation` and `photoDirection` as off: it never asks for the location, follows neither the location nor
    /// the compass, and calls no `locationProvider`.
    var canCarryLocation: Bool {
        output.metadata == .kept || photoLibrarySaving.isPossible
    }
}
