//
//  FlowExitAlert.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The system alert that asks before the cross leaves photos behind: it counts the photos of the set and the ones the
/// camera is still taking or processing (`CameraFlowModel.exitConfirmation`).
struct FlowExitAlert: ViewModifier {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel

    func body(content: Content) -> some View {
        let isPresented = Binding {
            flow.exitConfirmation != nil
        } set: { isPresented in
            if !isPresented {
                flow.cancelExit()
            }
        }
        let title = FlowText(localization).exitTitle
        content.alert(title, isPresented: isPresented, presenting: flow.exitConfirmation) { _ in
            Button(FlowText(localization).exitStay, role: .cancel, action: flow.cancelExit)
            Button(FlowText(localization).exitLeave, role: .destructive, action: flow.confirmExit)
        } message: { confirmation in
            Text(FlowText(localization).exitMessage(for: confirmation))
        }
    }
}
#endif
