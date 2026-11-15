//
//  MarkupTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Markup text and identifiers")
struct MarkupTextTests {

    @Test("The top bar of the drawing mode has its names")
    func topBar() {
        #expect(MarkupText(.system).cancel == "Cancel")
        #expect(MarkupText(.system).undo == "Undo")
        #expect(MarkupText(.system).redo == "Redo")
        #expect(MarkupText(.system).done == "Done")
        #expect(MarkupText(.system).canvas == "Drawing")
    }

    @Test("The discard dialog has a title and its destructive answer")
    func discardDialog() {
        #expect(MarkupText(.system).discardTitle == "Discard the drawing?")
        #expect(MarkupText(.system).discardDrawing == "Discard")
    }

    @Test(
        "A notice of the drawing mode says what could not be done",
        arguments: [
            (MarkupNotice.cannotOpen, "Markup could not be opened"),
            (.cannotKeep, "The drawing could not be saved")
        ]
    )
    func notice(notice: MarkupNotice, message: String) {
        #expect(MarkupText(.system).message(for: notice) == message)
    }

    @Test("The controls of the drawing mode have stable identifiers")
    func identifiers() {
        #expect(FlowIdentifier.markupCancel == "flow.markup.cancel")
        #expect(FlowIdentifier.markupUndo == "flow.markup.undo")
        #expect(FlowIdentifier.markupRedo == "flow.markup.redo")
        #expect(FlowIdentifier.markupDone == "flow.markup.done")
        #expect(FlowIdentifier.markupCanvas == "flow.markup.canvas")
    }
}
