//
//  View+Concealment.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension View {

    /// Fades the view out and takes it out of touch and accessibility, as for the controls the control panel card
    /// covers and for the mode that is not shown. The view stays in the tree, so it keeps its identity and its
    /// state.
    func concealed(_ isConcealed: Bool) -> some View {
        opacity(isConcealed ? 0 : 1)
            .allowsHitTesting(!isConcealed)
            .accessibilityHidden(isConcealed)
    }
}
#endif
