//
//  Notification.Name+UndoState.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

extension Notification.Name {
    /// What an undo manager posts once it has more or less to undo or to redo: after an action was registered,
    /// after an undo and after a redo. The engines report a change of the drawing before their undo manager has
    /// moved, so a canvas reads its undo and redo anew on these.
    static let undoStateChanges: [Notification.Name] = [
        .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange
    ]
}
