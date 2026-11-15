//
//  PhotoShot.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What one photo is taken with, as the shutter fires: the request the running camera takes, and the pipeline that
/// turns the photo it delivers into files.
struct PhotoShot {
    let request: PhotoCaptureRequest
    let pipeline: PhotoCapturePipeline
}
