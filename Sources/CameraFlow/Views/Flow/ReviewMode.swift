//
//  ReviewMode.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The review of the set, above the bottom bar it shares with the shooting mode: the pages of the photos, the top
/// bar and the strip. While a photo is drawn on, the drawing mode takes the place of the top bar and the strip.
struct ReviewMode: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let layout: CameraScreenLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    var body: some View {
        let markup = flow.markup
        ZStack(alignment: .topLeading) {
            ReviewPager(review: flow.review, photoSet: flow.photoSet, markup: markup, layout: layout)
            ReviewTopBar(flow: flow, layout: layout, focus: focus)
                .concealed(markup.isOpen)
            ReviewStrip(flow: flow, layout: layout.reviewStrip(isRightToLeft: localization.isRightToLeft))
                .concealed(markup.isOpen)
            if let session = markup.session {
                MarkupMode(markup: markup, session: session, layout: layout, focus: focus)
                    .transition(.opacity)
            }
        }
        .animation(FlowMotion.markupChange, value: markup.isOpen)
    }
}
#endif
