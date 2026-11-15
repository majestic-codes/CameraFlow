//
//  FlowAccessibilityActions.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the VoiceOver escape gesture, a two-finger scrub, closes on the flow's screen: the layer on top.
enum FlowEscape: Equatable, Sendable {
    /// The drawing, which asks before a changed drawing is discarded, as its Cancel does.
    case cancelDrawing
    /// The control panel.
    case closePanel
    /// The flow, which asks before a set with photos is left, as its cross does.
    case leaveFlow

    init(isDrawing: Bool, isPanelOpen: Bool) {
        if isDrawing {
            self = .cancelDrawing
        } else if isPanelOpen {
            self = .closePanel
        } else {
            self = .leaveFlow
        }
    }
}

/// The control VoiceOver moves to when the one it was on goes away with what it opened or closed, so that the user
/// goes on from there and does not look for the screen's new state.
enum FlowFocusTarget: Hashable, Sendable {
    case shutter
    /// The button beside the shutter that opens the control panel.
    case cameraControls
    /// The tile of a setting in the control panel.
    case panelTile(CameraSetting)
    /// The title of the sub-panel that is open.
    case subPanelTitle
    /// Cancel of the drawing.
    case cancelDrawing
    /// The Markup button of the review, which opens the drawing.
    case markup

    /// Where the focus goes once the introduction is over: the shutter of the camera it gave way to.
    static let afterIntroduction = Self.shutter

    /// Where the focus goes as the control panel changes: the first tile as the tiles open, the title of a sub-panel
    /// as it opens, the tile of its setting as a sub-panel gives way to the tiles, and the button that opens the panel
    /// as the panel closes. Nil for tiles that open while the panel has none.
    static func afterPanel(
        from previous: CameraPanelPresentation,
        to presentation: CameraPanelPresentation,
        tiles: [CameraSetting]
    ) -> Self? {
        switch (previous, presentation) {
        case (_, .hidden): .cameraControls
        case (_, .subPanel): .subPanelTitle
        case let (.subPanel(setting), .tiles): .panelTile(setting)
        case (.hidden, .tiles), (.tiles, .tiles): tiles.first.map(Self.panelTile)
        }
    }

    /// Where the focus goes as the drawing opens or closes: its Cancel, or the Markup button that opened it.
    static func afterDrawing(isOpen: Bool) -> Self {
        isOpen ? .cancelDrawing : .markup
    }
}
