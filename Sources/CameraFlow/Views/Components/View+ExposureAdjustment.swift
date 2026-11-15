//
//  View+ExposureAdjustment.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Lets VoiceOver adjust the exposure bias on the view: a swipe up or down hands `step` the bias of one tick of
    /// the exposure ruler, up or down.
    func exposureAdjustableAction(_ step: @escaping (Double) -> Void) -> some View {
        accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(SubPanelRulerScale.tickBias)
            case .decrement: step(-SubPanelRulerScale.tickBias)
            @unknown default: break
            }
        }
    }
}
#endif
