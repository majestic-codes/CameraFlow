//
//  FlashUnavailableAlert.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The system alert that says why the flash cannot fire, after a tap on the Flash indicator, as the stock camera says
/// it. It closes by itself once the flash can fire again.
struct FlashUnavailableAlert: ViewModifier {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    func body(content: Content) -> some View {
        let text = FlashUnavailableText(localization)
        let isPresented = Binding {
            settings.flash.explanation != nil
        } set: { isPresented in
            if !isPresented {
                settings.dismissFlashExplanation()
            }
        }
        content.alert(text.title, isPresented: isPresented, presenting: settings.flash.explanation) { _ in
            Button(text.dismiss, role: .cancel, action: settings.dismissFlashExplanation)
        } message: { reason in
            Text(text.message(for: reason, on: .current))
        }
    }
}
#endif
