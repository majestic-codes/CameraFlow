//
//  ControlPanelStack.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The control panel and the sub-panel on one glass card. The card grows out of the shutter, changes its height between
/// the tiles and a sub-panel and shrinks back into the shutter, while the content of each state blurs in and out. For
/// people who reduce motion the card fades in and out at the size of what it shows, the contents cross-fade, and the
/// lens row, the dial and the shutter, which a sub-panel lifts, take their places at once (`PanelLiftMotion`). Dragging
/// the grabber down moves the card with the finger and closes it past a threshold. On a hardware keyboard Escape closes
/// the tiles and takes a sub-panel back to them.
struct ControlPanelStack: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let panel: ControlPanelModel
    let settings: PhotoSettingsModel
    let dualCamera: DualCameraModel
    let layout: CameraScreenLayout
    let toggleDualCamera: () async -> Void
    /// The control VoiceOver goes to as the panel changes, which the screen moves.
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding
    /// Whether the panel's buttons take the keys of a hardware keyboard now.
    let takesKeyboardShortcuts: Bool

    @State private var dragOffset: CGFloat = 0
    /// Whether a finger drags the grabber. It goes back to false when the drag ends and when the system takes it
    /// away.
    @GestureState private var isDraggingGrabber = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            card
            CameraControlPanel(panel: panel, settings: settings, dualCamera: dualCamera, layout: layout, focus: focus)
            CameraSubPanel(
                panel: panel,
                settings: settings,
                dualCamera: dualCamera,
                layout: layout,
                toggleDualCamera: toggleDualCamera,
                focus: focus,
                takesKeyboardShortcuts: takesKeyboardShortcuts
            )
            if panel.presentation == .tiles {
                Color.clear
                    .contentShape(Rectangle())
                    .placed(in: layout.controlPanelGrabberTouchArea)
                    .gesture(grabberDrag)
                // To accessibility and to a hardware keyboard the grabber is the button that closes the panel, as a
                // sheet's grabber is, and Escape presses it. A finger only drags it.
                Button(action: panel.dismiss) {
                    Color.clear
                }
                .buttonStyle(.plain)
                .allowsHitTesting(false)
                .keyboardShortcut(.cancelAction, isActive: takesKeyboardShortcuts)
                .accessibilityIdentifier(CameraIdentifier.panelDismiss)
                .accessibilityLabel(CameraControlText(localization).dismissControls)
                .placed(in: layout.controlPanelGrabberTouchArea)
            }
        }
        .offset(y: dragOffset)
        .onChange(of: panel.presentation) {
            withAnimation(CameraMotion.Panel.animation(to: panel.presentation)) {
                dragOffset = 0
            }
        }
        .onChange(of: isDraggingGrabber) { _, isDragging in
            // A drag the system took away settles the card back, as a drag too short to close it does.
            guard !isDragging, dragOffset != 0, panel.presentation == .tiles else { return }
            withAnimation(CameraMotion.Panel.dragSettle) {
                dragOffset = 0
            }
        }
    }

    private static let cardShape = RoundedRectangle(
        cornerRadius: CameraMetrics.ControlPanel.cornerRadius,
        style: .continuous
    )

    /// The glass card in the frame of what the panel shows. It stays while the panel is closed, as the blob around
    /// the shutter it grows from, except for people who reduce motion: for them it comes and goes at the size of what
    /// it shows. It has no accessibility modifier: any of them, hiding too, makes it an element, and the closed card
    /// would then stand over the shutter for an accessibility hit test.
    @ViewBuilder private var card: some View {
        let glass = Color.clear
            .cameraGlass(.overPreview, in: Self.cardShape)
            .contentShape(Self.cardShape)
            .placed(in: layout.panelCard)
        if reduceMotion {
            if panel.isOpen {
                glass
                    .transition(.opacity)
            }
        } else {
            glass
                .opacity(panel.isOpen ? 1 : 0)
                .allowsHitTesting(panel.isOpen)
        }
    }

    private var grabberDrag: some Gesture {
        DragGesture(minimumDistance: CameraMetrics.ControlPanel.grabberMinimumDistance, coordinateSpace: .global)
            .updating($isDraggingGrabber) { _, isDragging, _ in
                isDragging = true
            }
            .onChanged { value in
                dragOffset = ControlPanelDrag.offset(forTranslation: value.translation.height)
            }
            .onEnded { value in
                let translation = value.translation.height
                let predicted = value.predictedEndTranslation.height
                if ControlPanelDrag.dismisses(translation: translation, predictedTranslation: predicted) {
                    panel.dismiss()
                } else {
                    withAnimation(CameraMotion.Panel.dragSettle) {
                        dragOffset = 0
                    }
                }
            }
    }
}

extension AnyTransition {

    /// How the content of the panel card gives way to the next one: it blurs out as the next one blurs in, and for
    /// people who reduce motion the two cross-fade.
    @MainActor
    static func panelContent(reducesMotion: Bool) -> AnyTransition {
        reducesMotion ? .opacity : AnyTransition(.blurReplace)
    }
}
#endif
