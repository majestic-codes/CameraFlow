//
//  ModeSwitchLabels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The two labels of the mode switch in one colour, each in its pill. The switch draws the row twice, in white
/// and in the accent colour, and shows the accent row only under the thumb.
struct ModeSwitchLabels: View {
    @Environment(\.flowLocalization) private var localization
    /// The layout inside the capsule.
    let layout: ModeSwitchLayout
    let color: Color
    let isReviewAvailable: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            label(.shooting)
            label(.review)
        }
        .frame(width: layout.frame.width, height: layout.frame.height, alignment: .topLeading)
        .foregroundStyle(color)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func label(_ mode: CameraFlowMode) -> some View {
        let isDimmed = mode == .review && !isReviewAvailable
        return Text(FlowText(localization).modeLabel(mode))
            .font(CameraTypography.modeLabel)
            .tracking(CameraTypography.modeLabelTracking(LetterTracking(localization)))
            .lineLimit(1)
            .minimumScaleFactor(FlowMetrics.ModeSwitch.labelMinimumScale)
            .opacity(isDimmed ? CameraPalette.unavailableOpacity : 1)
            .animation(FlowMotion.availability, value: isDimmed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .placed(in: layout.segment(mode))
    }
}
#endif
