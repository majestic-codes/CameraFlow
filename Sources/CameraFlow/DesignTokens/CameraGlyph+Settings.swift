//
//  CameraGlyph+Settings.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

extension CameraGlyph {
    /// The glyph of a flash mode.
    init(flashMode: CameraFlowFlashMode) {
        switch flashMode {
        case .auto: self = .flashAuto
        case .alwaysOn: self = .flashOn
        case .off: self = .flashOff
        }
    }

    /// The glyph of the Flash indicator in a mode. Auto is outlined while the scene would not fire the flash for
    /// people who differentiate without colour, since the colour of the lit indicator alone tells the two apart.
    init(flashMode: CameraFlowFlashMode, isLit: Bool, differentiatesWithoutColor: Bool) {
        guard flashMode == .auto, !isLit, differentiatesWithoutColor else {
            self.init(flashMode: flashMode)
            return
        }
        self = .flashAutoUnlit
    }

    /// The glyph of Live Photo switched on or off.
    init(isLivePhotoOn: Bool) {
        self = isLivePhotoOn ? .livePhotoOn : .livePhotoOff
    }

    /// The glyph of an aspect ratio.
    init(aspectRatio: CameraFlowAspectRatio) {
        switch aspectRatio {
        case .fourByThree: self = .aspect4x3
        case .sixteenByNine: self = .aspect16x9
        case .square: self = .aspect1x1
        }
    }

    /// The glyph of a self-timer delay.
    init(timer: CameraFlowTimer) {
        switch timer {
        case .off: self = .timerOff
        case .threeSeconds: self = .timer3
        case .fiveSeconds: self = .timer5
        case .tenSeconds: self = .timer10
        }
    }
}
