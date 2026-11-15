//
//  View+KeyboardShortcut.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Gives a button a key of a hardware keyboard while it is active, and none otherwise: a control that is
    /// concealed or covered stays in the tree and would still answer its key.
    func keyboardShortcut(_ shortcut: KeyboardShortcut, isActive: Bool) -> some View {
        keyboardShortcut(isActive ? shortcut : nil)
    }
}
#endif
