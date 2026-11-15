//
//  FlowAccessibilityActionsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The escape gesture and the focus of VoiceOver on the flow's screen")
struct FlowAccessibilityActionsTests {

    @Test(
        "The escape gesture closes the layer on top: the drawing, then the control panel, then the flow",
        arguments: [
            (true, true, FlowEscape.cancelDrawing),
            (true, false, .cancelDrawing),
            (false, true, .closePanel),
            (false, false, .leaveFlow)
        ]
    )
    func escape(isDrawing: Bool, isPanelOpen: Bool, expected: FlowEscape) {
        #expect(FlowEscape(isDrawing: isDrawing, isPanelOpen: isPanelOpen) == expected)
    }

    @Test("The focus goes to Cancel of a drawing that opens, and back to the Markup button when it closes")
    func drawing() {
        #expect(FlowFocusTarget.afterDrawing(isOpen: true) == .cancelDrawing)
        #expect(FlowFocusTarget.afterDrawing(isOpen: false) == .markup)
    }

    @Test("The focus goes to the shutter after the introduction")
    func introduction() {
        #expect(FlowFocusTarget.afterIntroduction == .shutter)
    }

    @Test(
        "The focus goes to the first tile, to a sub-panel's title, back to its tile and to the panel's button",
        arguments: [
            (CameraPanelPresentation.hidden, CameraPanelPresentation.tiles, FlowFocusTarget.panelTile(.flash)),
            (.tiles, .subPanel(.timer), .subPanelTitle),
            (.hidden, .subPanel(.aspect), .subPanelTitle),
            (.subPanel(.timer), .subPanel(.aspect), .subPanelTitle),
            (.subPanel(.timer), .tiles, .panelTile(.timer)),
            (.subPanel(.flash), .tiles, .panelTile(.flash)),
            (.tiles, .hidden, .cameraControls),
            (.subPanel(.timer), .hidden, .cameraControls)
        ]
    )
    func panel(previous: CameraPanelPresentation, presentation: CameraPanelPresentation, expected: FlowFocusTarget) {
        let tiles: [CameraSetting] = [.flash, .live, .aspect, .timer]
        #expect(FlowFocusTarget.afterPanel(from: previous, to: presentation, tiles: tiles) == expected)
    }

    @Test("Tiles that open without a tile take the focus nowhere")
    func panelWithoutTiles() {
        #expect(FlowFocusTarget.afterPanel(from: .hidden, to: .tiles, tiles: []) == nil)
    }
}
