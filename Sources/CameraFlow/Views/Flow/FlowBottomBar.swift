//
//  FlowBottomBar.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The bar both modes share: the cross that leaves the flow, the mode switch and the check mark that hands the
/// set over. The control panel covers the bar while it is open, and the system tool picker takes its place while a
/// photo is drawn on. On a hardware keyboard Escape is the cross and Return the check mark, while the bar is shown
/// and nothing of the flow stands over it.
struct FlowBottomBar: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let panel: ControlPanelModel
    let layout: CameraScreenLayout
    let modeSwitch: ModeSwitchLayout
    /// How many small copies of fresh photos have landed in the review segment.
    let landedCaptureCount: Int
    /// Whether the screen's controls take the keys of a hardware keyboard now.
    let takesKeyboardShortcuts: Bool

    var body: some View {
        let isConcealed = panel.isOpen || flow.markup.isOpen
        let takesKeys = takesKeyboardShortcuts && !isConcealed
        ZStack(alignment: .topLeading) {
            GlassCircleButton(diameter: CameraMetrics.SideButton.diameter, action: flow.requestExit) {
                FlowGlyphView(glyph: .cross)
            }
            .keyboardShortcut(.cancelAction, isActive: takesKeys)
            .accessibilityIdentifier(FlowIdentifier.exit)
            .accessibilityLabel(FlowText(localization).exit)
            .showsLargeContent(FlowText(localization).exit)
            .placed(in: layout.exit)
            FlowModeSwitch(
                flow: flow,
                photoSet: flow.photoSet,
                layout: modeSwitch,
                landedCaptureCount: landedCaptureCount
            )
            FlowAcceptButton(isEnabled: flow.canAccept, isHandingOver: flow.isHandingOver) {
                Task {
                    await flow.accept()
                }
            }
            .keyboardShortcut(.defaultAction, isActive: takesKeys)
            .accessibilityIdentifier(FlowIdentifier.accept)
            .accessibilityLabel(FlowText(localization).accept)
            .accessibilityValue(flow.isHandingOver ? FlowText(localization).handingOver : "")
            .showsLargeContent(FlowText(localization).accept)
            .placed(in: layout.accept)
            .onChange(of: flow.isHandingOver) { _, isHandingOver in
                if isHandingOver {
                    AccessibilityNotification.Announcement(FlowText(localization).handingOver).post()
                }
            }
        }
        .concealed(isConcealed)
    }
}
#endif
