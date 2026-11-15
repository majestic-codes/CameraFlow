//
//  MarkupTopBar.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The top bar of the drawing mode: "Cancel" with the dialog that asks before a changed drawing is discarded,
/// undo and redo, which dim while there is nothing to take back or to bring back, and "Done". On a hardware keyboard
/// Escape is Cancel, Return is Done, Command-Z undoes and Shift-Command-Z redoes, while no dialog is up.
struct MarkupTopBar: View {
    @Environment(\.flowLocalization) private var localization
    let markup: EmbeddedPhotoMarkupModel
    let layout: MarkupTopBarLayout
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    /// The widths of the two labels in the current language.
    static func labelWidths(in localization: FlowLocalization) -> MarkupLabelWidths {
        let text = MarkupText(localization)
        return MarkupLabelWidths(
            cancel: CameraTypography.markupCancelWidth(text.cancel),
            done: CameraTypography.markupDoneWidth(text.done)
        )
    }

    var body: some View {
        let text = MarkupText(localization)
        let takesKeys = !markup.isDiscardConfirmationPresented && !markup.isFinishing
        ZStack(alignment: .topLeading) {
            MarkupCapsuleButton(label: text.cancel, isProminent: false, action: markup.cancel)
                .keyboardShortcut(.cancelAction, isActive: takesKeys)
                .modifier(MarkupDiscardDialog(markup: markup))
                .accessibilityIdentifier(FlowIdentifier.markupCancel)
                .accessibilityFocused(focus, equals: .cancelDrawing)
                .showsLargeContent(text.cancel)
                .placed(in: layout.cancel)
            stepButton(layout.undoGlyph, isEnabled: markup.canUndo, action: markup.undo)
                .keyboardShortcut(KeyboardShortcut("z", modifiers: .command), isActive: takesKeys)
                .accessibilityIdentifier(FlowIdentifier.markupUndo)
                .accessibilityLabel(text.undo)
                .showsLargeContent(text.undo)
                .placed(in: layout.undoTouchArea)
            stepButton(layout.redoGlyph, isEnabled: markup.canRedo, action: markup.redo)
                .keyboardShortcut(KeyboardShortcut("z", modifiers: [.command, .shift]), isActive: takesKeys)
                .accessibilityIdentifier(FlowIdentifier.markupRedo)
                .accessibilityLabel(text.redo)
                .showsLargeContent(text.redo)
                .placed(in: layout.redoTouchArea)
            MarkupCapsuleButton(label: text.done, isProminent: true) {
                Task {
                    await markup.finish()
                }
            }
            .keyboardShortcut(.defaultAction, isActive: takesKeys)
            .accessibilityIdentifier(FlowIdentifier.markupDone)
            .showsLargeContent(text.done)
            .placed(in: layout.done)
        }
        .allowsHitTesting(!markup.isFinishing)
    }

    /// Undo or redo: the glass of the mock-up, which takes a touch in the larger circle a finger needs.
    private func stepButton(_ glyph: FlowGlyph, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        let metrics = FlowMetrics.MarkupTopBar.self
        return GlassCircleButton(
            diameter: metrics.stepButtonDiameter,
            touchDiameter: metrics.stepButtonTouchDiameter,
            action: action
        ) {
            FlowGlyphView(glyph: glyph)
        }
        .disabled(!isEnabled)
    }
}

/// A capsule with a label in the top bar of the drawing mode: white on glass, or dark on the accent colour for
/// the action that keeps the drawing.
private struct MarkupCapsuleButton: View {
    let label: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(isProminent ? CameraTypography.markupDone : CameraTypography.markupCancel)
                .lineLimit(1)
                .minimumScaleFactor(FlowMetrics.MarkupTopBar.labelMinimumScale)
                .foregroundStyle(isProminent ? CameraPalette.onAccent : CameraPalette.label)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(CameraPalette.accent).opacity(isProminent ? 1 : 0))
                .cameraGlass(.control, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif
