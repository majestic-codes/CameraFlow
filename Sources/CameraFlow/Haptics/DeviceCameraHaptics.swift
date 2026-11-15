//
//  DeviceCameraHaptics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

/// The camera's haptics on the Taptic Engine. The stock camera plays a selection feedback for the panel, the
/// options, the flip button and the mode switch, and a light transient for the dial ticks. A refused pull of the
/// switch is a light impact. A generator is readied when a gesture that may end in its haptic begins, and again after
/// each haptic, for the next one that comes soon.
@MainActor
final class DeviceCameraHaptics: CameraHaptics {
    private let selection = UISelectionFeedbackGenerator()
    private let refusal = UIImpactFeedbackGenerator(style: .light)
    private let dial = DialHapticPlayer()

    func play(_ event: CameraHapticEvent) {
        switch event {
        case .dialTick:
            dial.tick()
        case .modeRefused:
            refusal.impactOccurred()
            refusal.prepare()
        case .settingOpened, .optionSelected, .cameraFlipped, .modeSelected:
            selection.selectionChanged()
            selection.prepare()
        }
    }

    /// The dial's engine starts with its first tick and stays ready while the dial turns, so a dial tick needs
    /// nothing readied here.
    func prepare(for event: CameraHapticEvent) {
        switch event {
        case .dialTick:
            break
        case .modeRefused:
            refusal.prepare()
        case .settingOpened, .optionSelected, .cameraFlipped, .modeSelected:
            selection.prepare()
        }
    }
}
#endif
