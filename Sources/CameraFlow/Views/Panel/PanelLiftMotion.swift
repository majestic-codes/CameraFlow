//
//  PanelLiftMotion.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// How the controls a sub-panel lifts, the lens row with the dial and the shutter, take their places as the panel
/// changes: with the card's spring, and for people who reduce motion at once, in the same places, without the slide.
struct PanelLiftMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    let panel: ControlPanelModel

    func body(content: Content) -> some View {
        let reducesMotion = reducesMotion
        content.transaction(value: panel.presentation) { transaction in
            if reducesMotion {
                transaction.animation = nil
            }
        }
    }
}
#endif
