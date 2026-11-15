//
//  TouchDownButtonStyle.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A button that looks as the system's plain style draws one, dimmed while a finger is on it and while it is
/// disabled, and that tells `onTouchDown` when a finger comes down on it. A button whose action plays a haptic readies
/// the haptic there, ahead of the action, which runs as the finger lifts.
struct TouchDownButtonStyle: ButtonStyle {
    let onTouchDown: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        TouchDownButtonLabel(configuration: configuration, onTouchDown: onTouchDown)
    }
}

/// The label of a button of `TouchDownButtonStyle`, which reads whether the button is enabled.
private struct TouchDownButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let onTouchDown: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .opacity(configuration.isPressed ? CameraPalette.pressedButtonOpacity : 1)
            .opacity(isEnabled ? 1 : CameraPalette.disabledButtonOpacity)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    onTouchDown()
                }
            }
    }
}
#endif
