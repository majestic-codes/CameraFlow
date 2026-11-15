//
//  CaptureControlTitle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// The texts of the controls the flow adds to the Camera Control, the side button of iPhone 16 and later, in the
/// flow's language.
enum CaptureControlTitle {

    /// The title of the lens picker, as the system Camera names it.
    static func lensPicker(_ localization: FlowLocalization) -> String {
        String(
            localized: "camera.captureControl.lenses",
            defaultValue: "Cameras",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// The title of a lens in the lens picker, such as "0.5×", with the numbers of the flow's language.
    static func lens(_ lens: CameraLens, _ localization: FlowLocalization) -> String {
        ZoomFactorTitle.current(lens.factor, localization: localization)
    }
}
