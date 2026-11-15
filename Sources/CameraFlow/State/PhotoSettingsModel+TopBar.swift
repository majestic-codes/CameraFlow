//
//  PhotoSettingsModel+TopBar.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The top bar

extension PhotoSettingsModel {
    /// The settings with a control in the top bar whatever their value, in their order from the left.
    var topBarSettings: [CameraSetting] {
        [.flash, .live, .dualCamera, .librarySave].filter(isAdjustable)
    }

    /// The settings the user may change whose value in effect is not the stock default, in the order of their
    /// tiles: each gets an indicator in the top bar after the controls, like the stock camera. A setting the app
    /// fixed is the app's choice, not the user's, and has none.
    var changedSettings: [CameraSetting] {
        [.aspect, .timer, .exposure, .format].filter { isAdjustable($0) && isChanged($0) }
    }

    /// Everything in the top bar from the left: the controls, then the indicators of the changed settings.
    var topBarItems: [CameraSetting] {
        topBarSettings + changedSettings
    }

    private func isChanged(_ setting: CameraSetting) -> Bool {
        switch setting {
        case .aspect: aspectRatio != .fourByThree
        case .timer: timer != .off
        case .exposure: displayedExposureBias != 0
        case .format: effectivePhotoFormat == .raw || quality.isReduced
        case .flash, .live, .dualCamera, .librarySave: false
        }
    }
}

// MARK: - The exposure bias as the screen writes it

extension PhotoSettingsModel {
    /// The step the screen writes an exposure bias in, a tenth of a stop.
    nonisolated static let displayedExposureBiasStep = 0.1

    /// A bias as the screen writes it: rounded to a tenth of a stop, and 0, never -0, where it rounds to nothing.
    nonisolated static func displayedExposureBias(_ bias: Double) -> Double {
        let steps = (bias / displayedExposureBiasStep).rounded()
        return steps == 0 ? 0 : steps * displayedExposureBiasStep
    }

    /// The exposure bias as the screen writes it. A drag that ends a hair off zero reads as no bias and leaves no
    /// indicator in the top bar, while the camera keeps the bias the finger set.
    var displayedExposureBias: Double {
        Self.displayedExposureBias(exposureBias)
    }
}
