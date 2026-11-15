//
//  RecordingCameraService+HeldCaptures.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

extension RecordingCameraService {

    /// Lets the first `count` held captures go on one after the other, each once the one before it has ended. The
    /// simulated camera then never encodes two photos at once, which can hang on a simulator.
    func releaseHeldCaptures(inTurn count: Int) async {
        for _ in 0..<count {
            let endedCount = endedCaptureCount
            releaseHeldCapture(at: 0)
            await settle { endedCaptureCount > endedCount }
        }
    }
}
