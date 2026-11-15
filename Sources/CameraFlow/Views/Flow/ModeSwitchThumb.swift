//
//  ModeSwitchThumb.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The thumb of the mode switch, which rests under the selected mode and follows a finger: liquid glass where the
/// system has it, a light capsule before.
struct ModeSwitchThumb: View {
    /// Where the thumb is, inside the capsule.
    let frame: CGRect
    /// How much the thumb stretches along its way, 0 at rest.
    let stretch: CGFloat

    private static let rimWidth = FlowMetrics.ModeSwitch.selectedRimWidth

    var body: some View {
        surface
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .thumbPlaced(frame, stretch: stretch)
    }

    @ViewBuilder private var surface: some View {
        if #available(iOS 26, *) {
            Color.clear.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(CameraPalette.selectedSegment)
                .overlay {
                    Capsule()
                        .strokeBorder(CameraPalette.selectedSegmentRim, lineWidth: Self.rimWidth)
                }
        }
    }
}

extension View {

    /// Gives the view the size and place of a thumb, stretched along its way and squeezed across it by half as
    /// much. The glass and the mask of the accent labels use it alike, so the colour follows the glass.
    func thumbPlaced(_ frame: CGRect, stretch: CGFloat) -> some View {
        self
            .frame(width: frame.width, height: frame.height)
            .scaleEffect(x: 1 + stretch, y: 1 - stretch / 2)
            .offset(x: frame.minX, y: frame.minY)
    }
}
#endif
