//
//  ControlPanelModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The control panel: closed, the grid of setting tiles, or the sub-panel of one setting.
@MainActor
@Observable
final class ControlPanelModel {
    private(set) var presentation: CameraPanelPresentation
    /// The settings with a tile, in the order of the grid.
    let settings: [CameraSetting]

    @ObservationIgnored private let haptics: any CameraHaptics

    /// - Precondition: a sub-panel in `presentation` is the one of a setting in `settings`.
    init(settings: [CameraSetting], presentation: CameraPanelPresentation, haptics: any CameraHaptics) {
        if case let .subPanel(setting) = presentation {
            precondition(settings.contains(setting), "The control panel has no \(setting) setting to open")
        }
        self.settings = settings
        self.presentation = presentation
        self.haptics = haptics
    }

    var isOpen: Bool {
        presentation != .hidden
    }

    /// Shows the tiles, whose tap opens a sub-panel with a haptic that is readied now.
    func showTiles() {
        presentation = .tiles
        haptics.prepare(for: .settingOpened)
    }

    func showSubPanel(_ setting: CameraSetting) {
        presentation = .subPanel(setting)
        haptics.play(.settingOpened)
    }

    /// A finger came down on a tile: the haptic of the sub-panel its release opens is readied.
    func tileTouched() {
        haptics.prepare(for: .settingOpened)
    }

    func dismiss() {
        presentation = .hidden
    }
}
