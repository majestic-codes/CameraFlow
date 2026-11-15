//
//  MarkupUndoObservation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Hears one undo manager at a time tell that it has more or less to undo or to redo.
///
/// An `NSObject`, so that the notification centre calls it by selector and lets it go when it goes.
@MainActor
final class MarkupUndoObservation: NSObject {
    private var handler: @MainActor () -> Void = {}

    /// Hears `undoManager` from now on, and no undo manager heard before. Without an undo manager it hears none.
    func observe(_ undoManager: UndoManager?, onChange handler: @escaping @MainActor () -> Void) {
        stop()
        guard let undoManager else {
            return
        }
        self.handler = handler
        for name in Notification.Name.undoStateChanges {
            let selector = #selector(undoStateChanged)
            NotificationCenter.default.addObserver(self, selector: selector, name: name, object: undoManager)
        }
    }

    /// Hears no undo manager any more.
    func stop() {
        for name in Notification.Name.undoStateChanges {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        handler = {}
    }

    @objc private func undoStateChanged() {
        handler()
    }
}
