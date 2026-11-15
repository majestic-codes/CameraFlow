//
//  PhotoMarkupFinishTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("Photo markup: Done while it reads the drawing", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoMarkupFinishTests {
    let harness = FlowHarness()

    @Test("While Done reads the drawing, undo, redo, cancel, discard and a second Done do nothing")
    func finishingRefusesTheRest() async throws {
        let gate = CallGate()
        harness.canvasOpener.readGate = gate
        let (flow, canvas) = try await harness.makeDrawnFlow()
        let drawing = try FlowTestSupport.makeDrawing()
        canvas.change(to: drawing, canUndo: true, canRedo: true)
        let finishing = Task { await flow.markup.finish() }
        await gate.arrival()
        #expect(flow.markup.isFinishing)
        flow.markup.undo()
        flow.markup.redo()
        flow.markup.cancel()
        flow.markup.discard()
        let secondFinish = Task { await flow.markup.finish() }
        await settleQueuedWork()
        #expect(canvas.undoCount == 0)
        #expect(canvas.redoCount == 0)
        #expect(canvas.readCount == 1)
        #expect(flow.markup.isOpen)
        #expect(flow.markup.isDiscardConfirmationPresented == false)
        await gate.open()
        await finishing.value
        await secondFinish.value
        #expect(flow.markup.isOpen == false)
        #expect(flow.markup.isFinishing == false)
        #expect(flow.review.currentPhoto?.drawing == drawing)
        flow.photoSet.discard()
    }
}
