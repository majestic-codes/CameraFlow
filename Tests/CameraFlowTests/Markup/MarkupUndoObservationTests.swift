//
//  MarkupUndoObservationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// How a canvas hears its undo manager tell that it has more or less to undo or to redo.
@Suite("Hearing the undo manager of a canvas")
@MainActor
struct MarkupUndoObservationTests {
    /// What the undo manager undoes, and how many times the observation was heard.
    private final class Record {
        var heardCount = 0
    }

    /// An undo manager that groups only what a test groups: no event loop runs to group by.
    private static func makeUndoManager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    /// One action, in a group of its own, as a stroke is.
    private static func registerAction(on undoManager: UndoManager, target: Record) {
        undoManager.beginUndoGrouping()
        registerReversibleChange(on: undoManager, target: target)
        undoManager.endUndoGrouping()
    }

    /// A change whose undo registers the change back, as the changes of a drawing do, so that it can be redone.
    private static func registerReversibleChange(on undoManager: UndoManager, target: Record) {
        undoManager.registerUndo(withTarget: target) { target in
            registerReversibleChange(on: undoManager, target: target)
        }
    }

    /// How many times an observation hears one action after it was told to observe `undoManager` that many times.
    private static func heardCount(ofOneActionObservedTimes times: Int) -> Int {
        let undoManager = makeUndoManager()
        let record = Record()
        let observation = MarkupUndoObservation()
        for _ in 0..<times {
            observation.observe(undoManager) { record.heardCount += 1 }
        }
        registerAction(on: undoManager, target: record)
        return record.heardCount
    }

    @Test("An action, its undo and its redo are each heard")
    func actionUndoRedo() {
        let undoManager = Self.makeUndoManager()
        let record = Record()
        let observation = MarkupUndoObservation()
        observation.observe(undoManager) { record.heardCount += 1 }
        Self.registerAction(on: undoManager, target: record)
        let afterAction = record.heardCount
        #expect(afterAction > 0)
        undoManager.undo()
        let afterUndo = record.heardCount
        #expect(afterUndo > afterAction)
        undoManager.redo()
        #expect(record.heardCount > afterUndo)
    }

    @Test("Observing the same undo manager again still hears each change once")
    func observingAgain() {
        let once = Self.heardCount(ofOneActionObservedTimes: 1)
        #expect(once > 0)
        #expect(Self.heardCount(ofOneActionObservedTimes: 3) == once)
    }

    @Test("A stopped observation hears nothing")
    func stopped() {
        let undoManager = Self.makeUndoManager()
        let record = Record()
        let observation = MarkupUndoObservation()
        observation.observe(undoManager) { record.heardCount += 1 }
        observation.stop()
        Self.registerAction(on: undoManager, target: record)
        undoManager.undo()
        #expect(record.heardCount == 0)
    }

    @Test("Only the undo manager observed last is heard")
    func lastUndoManager() {
        let first = Self.makeUndoManager()
        let second = Self.makeUndoManager()
        let record = Record()
        let observation = MarkupUndoObservation()
        observation.observe(first) { record.heardCount += 1 }
        observation.observe(second) { record.heardCount += 1 }
        Self.registerAction(on: first, target: record)
        #expect(record.heardCount == 0)
        Self.registerAction(on: second, target: record)
        #expect(record.heardCount > 0)
    }

    @Test("Observing no undo manager lets the one heard before go")
    func noUndoManager() {
        let undoManager = Self.makeUndoManager()
        let record = Record()
        let observation = MarkupUndoObservation()
        observation.observe(undoManager) { record.heardCount += 1 }
        observation.observe(nil) { record.heardCount += 1 }
        Self.registerAction(on: undoManager, target: record)
        #expect(record.heardCount == 0)
    }
}
