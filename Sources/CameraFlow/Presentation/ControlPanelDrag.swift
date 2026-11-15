//
//  ControlPanelDrag.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The drag of the control panel's grabber: the card follows a finger down and resists an upward pull, and a drag
/// far enough or fast enough closes the panel. Translations are in points, down positive.
enum ControlPanelDrag {
    private typealias Metrics = CameraMetrics.ControlPanel

    private static let resistance = RubberBand(
        limit: Metrics.dragResistanceLimit,
        stiffness: Metrics.dragResistanceStiffness
    )

    /// How far the card moves for a finger that has moved `translation` points.
    static func offset(forTranslation translation: CGFloat) -> CGFloat {
        guard translation < 0 else { return translation }
        return -resistance.offset(forOvershoot: -translation)
    }

    /// Whether a drag that ended `translation` points down, on its way to `predictedTranslation`, closes the panel.
    static func dismisses(translation: CGFloat, predictedTranslation: CGFloat) -> Bool {
        translation > Metrics.dismissDistance || predictedTranslation > Metrics.dismissPredictedDistance
    }
}
