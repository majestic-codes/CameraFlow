//
//  RecordingCameraService+Calls.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
@testable import CameraFlow

// MARK: - The record of the calls

extension RecordingCameraService {
    enum Call: Equatable {
        case start(CameraPosition)
        case startDualCamera(main: CameraPosition)
        case stop
        case setZoom(CGFloat)
        case rampZoom(CGFloat)
        case focus(CGPoint)
        case resetFocus
        case lockFocusAndExposure(CGPoint)
        case unlockFocusAndExposure
        case exposureBias(Double)
        case capture(PhotoCaptureRequest)
    }

    /// The calls since the first `count` of them.
    func calls(after count: Int) -> [Call] {
        Array(calls.dropFirst(count))
    }

    /// How many times the camera was started, alone or as a pair.
    var startCount: Int {
        calls.count { call in
            switch call {
            case .start, .startDualCamera: true
            default: false
            }
        }
    }

    /// Requests passed to `capturePhoto(_:)`, in order.
    var captureRequests: [PhotoCaptureRequest] {
        calls.compactMap { call in
            guard case let .capture(request) = call else { return nil }
            return request
        }
    }

    /// The flash modes of `monitoredFlashScenes`, in order.
    var monitoredFlashModes: [CameraFlowFlashMode] {
        monitoredFlashScenes.map(\.flashMode)
    }
}

/// A scene the camera was asked to monitor for the flash: in a mode, as a photo in a format would be taken.
struct MonitoredFlashScene: Equatable {
    let flashMode: CameraFlowFlashMode
    let format: CameraFlowPhotoFormat
}
