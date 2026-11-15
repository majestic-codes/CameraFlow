//
//  MarkupDiscardDialog.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The system dialog that asks before a changed drawing is discarded. It belongs on the cancel button: the system
/// grows it from the view it is attached to, and a tap outside it goes on with the drawing.
struct MarkupDiscardDialog: ViewModifier {
    @Environment(\.flowLocalization) private var localization
    let markup: EmbeddedPhotoMarkupModel

    func body(content: Content) -> some View {
        let isPresented = Binding {
            markup.isDiscardConfirmationPresented
        } set: { isPresented in
            if !isPresented {
                markup.dismissDiscardConfirmation()
            }
        }
        let title = MarkupText(localization).discardTitle
        content.confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(MarkupText(localization).discardDrawing, role: .destructive, action: markup.discard)
        }
    }
}
#endif
