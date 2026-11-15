//
//  ReviewTopBar.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The top of the review: the trash with the dialog that asks first, the place of the current photo in the set
/// and the Markup button, mirrored in a right-to-left language.
struct ReviewTopBar: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let layout: CameraScreenLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    var body: some View {
        let review = flow.review
        let diameter = FlowMetrics.CornerButton.diameter
        let bar = ReviewTopBarLayout(screen: layout, isRightToLeft: localization.isRightToLeft)
        ZStack(alignment: .topLeading) {
            GlassCircleButton(diameter: diameter, action: review.requestDelete) {
                FlowGlyphView(glyph: .trash)
            }
            .modifier(ReviewDeleteDialog(flow: flow))
            .accessibilityIdentifier(FlowIdentifier.reviewDelete)
            .accessibilityLabel(ReviewText(localization).deletePhoto)
            .showsLargeContent(ReviewText(localization).deletePhoto)
            .placed(in: bar.trash)
            if let position = review.currentPosition {
                counter(ReviewText(localization).counter(position), in: bar.counter)
            }
            GlassCircleButton(diameter: diameter, action: startMarkup) {
                FlowSymbolView(symbol: .markup, pointSize: FlowMetrics.MarkupSymbol.buttonPointSize, weight: .light)
            }
            .accessibilityIdentifier(FlowIdentifier.reviewMarkup)
            .accessibilityLabel(ReviewText(localization).markup)
            .accessibilityFocused(focus, equals: .markup)
            .showsLargeContent(ReviewText(localization).markup)
            .placed(in: bar.markup)
        }
    }

    /// Opens the drawing mode once the picture it lies over is ready.
    private func startMarkup() {
        Task {
            await flow.startMarkup()
        }
    }

    private func counter(_ text: String, in frame: CGRect) -> some View {
        Text(text)
            .font(CameraTypography.reviewCounter)
            .foregroundStyle(CameraPalette.label)
            .lineLimit(1)
            .accessibilityElement()
            .accessibilityIdentifier(FlowIdentifier.reviewCounter)
            .accessibilityLabel(ReviewText(localization).currentPhoto)
            .accessibilityValue(text)
            .showsLargeContent(text)
            .placed(in: frame)
    }
}
#endif
