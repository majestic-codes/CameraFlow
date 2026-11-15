//
//  ReviewDeleteDialog.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The system dialog that asks before the current photo is deleted. It belongs on the trash: the system grows it
/// from the view it is attached to, and a tap outside it cancels.
struct ReviewDeleteDialog: ViewModifier {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel

    func body(content: Content) -> some View {
        let review = flow.review
        let isPresented = Binding {
            review.deleteConfirmation != nil
        } set: { isPresented in
            if !isPresented {
                review.cancelDelete()
            }
        }
        content.confirmationDialog(
            ReviewText(localization).deleteTitle,
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: review.deleteConfirmation
        ) { confirmation in
            Button(ReviewText(localization).deletePhoto, role: .destructive) {
                Task {
                    await flow.deletePhoto(confirmedBy: confirmation)
                }
            }
        } message: { confirmation in
            Text(ReviewText(localization).deleteMessage(for: confirmation))
        }
    }
}
#endif
