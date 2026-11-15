//
//  FlowLocalizationEnvironment.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

private struct FlowLocalizationKey: EnvironmentKey {
    static let defaultValue = FlowLocalization.system
}

extension EnvironmentValues {
    /// The language of the flow's own texts and the locale of their numbers. `CameraFlowView` sets it from
    /// `CameraFlowConfiguration.language`.
    var flowLocalization: FlowLocalization {
        get { self[FlowLocalizationKey.self] }
        set { self[FlowLocalizationKey.self] = newValue }
    }
}

extension View {

    /// Writes the flow's texts in a language: the texts the views look up, the numbers SwiftUI formats and the
    /// direction of the views that follow the language.
    func flowLocalization(_ localization: FlowLocalization) -> some View {
        environment(\.flowLocalization, localization)
            .environment(\.locale, localization.locale)
            .transformEnvironment(\.layoutDirection) { direction in
                guard localization.isSystem == false else { return }
                direction = localization.isRightToLeft ? .rightToLeft : .leftToRight
            }
    }
}
#endif
