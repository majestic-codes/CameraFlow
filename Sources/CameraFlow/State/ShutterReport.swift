//
//  ShutterReport.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the camera has to say about a tap of the shutter, as `ShutterModel.capture(timer:began:shot:)` returns it.
enum ShutterReport {
    /// The tap took no photo: the set refused it or the capture failed.
    case failed(CameraServiceError)
    /// The photo was handed over without a part of its capture that failed.
    case handedOverWithout(CapturedPhotoLoss)
}
