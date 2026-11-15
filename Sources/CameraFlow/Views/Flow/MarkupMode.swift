//
//  MarkupMode.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The drawing mode over the photo of the review: the canvas exactly over the photo, which stays where the review
/// shows it, and the top bar. The system tool picker takes the bottom of the screen.
struct MarkupMode: View {
    @Environment(\.flowLocalization) private var localization
    let markup: EmbeddedPhotoMarkupModel
    let session: MarkupSession<EmbeddedMarkupCanvas>
    let layout: CameraScreenLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    var body: some View {
        let photoSize = CGSize(width: session.picture.width, height: session.picture.height)
        let topBar = MarkupTopBarLayout(
            screen: layout,
            labelWidths: MarkupTopBar.labelWidths(in: localization),
            isRightToLeft: localization.isRightToLeft
        )
        ZStack(alignment: .topLeading) {
            MarkupCanvasSurface(canvas: session.canvas)
                .id(ObjectIdentifier(session.canvas))
                .accessibilityIdentifier(FlowIdentifier.markupCanvas)
                .accessibilityLabel(MarkupText(localization).canvas)
                .placed(in: layout.reviewedPhotoFrame(photoSize: photoSize))
            MarkupTopBar(markup: markup, layout: topBar, focus: focus)
        }
    }
}
#endif
