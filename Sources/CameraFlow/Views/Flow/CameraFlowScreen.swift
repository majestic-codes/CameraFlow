//
//  CameraFlowScreen.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The whole screen of the flow: the camera or the review, with the bottom bar both modes share over them and
/// the control panel over the bar. Every component takes the models it shows and the layout, and places itself in
/// the coordinates of the whole screen. Every control is disabled while the set is being handed over.
///
/// VoiceOver's Magic Tap takes a photo where the hardware buttons do, and its escape gesture closes the layer on
/// top. A control that hides itself with what it opened or closed hands the VoiceOver focus on.
struct CameraFlowScreen: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    /// The touches on the zoom, made once with the flow.
    let zoomTouch: ZoomTouch

    @State private var landedCaptureCount = 0
    @AccessibilityFocusState private var focus: FlowFocusTarget?

    var body: some View {
        let camera = flow.camera
        GeometryReader { proxy in
            let layout = layout(in: proxy)
            let labelWidths = FlowModeSwitch.labelWidths(in: localization)
            let modeSwitch = ModeSwitchLayout(frame: layout.modeSwitch, labelWidths: labelWidths)
            let reviewSegment = modeSwitch.segment(.review)
            ZStack(alignment: .topLeading) {
                CameraPalette.background
                // The camera keeps following the phone while it is concealed, so it comes back turned the way the
                // phone is held.
                ShootingMode(flow: flow, layout: layout, zoomTouch: zoomTouch, focus: $focus)
                    .environment(\.cameraElementRotation, camera.orientation.elementRotation)
                    .concealed(flow.mode != .shooting)
                if flow.mode == .review {
                    ReviewMode(flow: flow, layout: layout, focus: $focus)
                        .transition(.opacity)
                }
                let isCircleShown = flow.mode == .shooting && camera.dualCamera.isOn
                CameraNoticeView(
                    notice: FlowText(localization).notice(for: flow),
                    frame: layout.notice(
                        isDualCameraCircleShown: isCircleShown,
                        isFocusLockBadgeShown: flow.mode == .shooting && camera.focus.lock == .locked,
                        elementOrientation: camera.orientation.elementRotation.orientation
                    )
                )
                FlowBottomBar(
                    flow: flow,
                    panel: camera.panel,
                    layout: layout,
                    modeSwitch: modeSwitch,
                    landedCaptureCount: landedCaptureCount,
                    takesKeyboardShortcuts: takesKeyboardShortcuts
                )
                CapturedPhotoFlight(
                    photoSet: flow.photoSet,
                    panel: camera.panel,
                    layout: layout,
                    landingPoint: CGPoint(x: reviewSegment.midX, y: reviewSegment.midY)
                ) {
                    landedCaptureCount += 1
                }
                ControlPanelStack(
                    panel: camera.panel,
                    settings: camera.settings,
                    dualCamera: camera.dualCamera,
                    layout: layout,
                    toggleDualCamera: camera.toggleDualCamera,
                    focus: $focus,
                    takesKeyboardShortcuts: takesKeyboardShortcuts
                )
                    .modifier(CaptureOverlayHiding(captureControls: camera.captureControls, panel: camera.panel))
                    // The panel belongs to the camera: its closed card, the glass blob around the shutter, would
                    // otherwise stand over the review's strip for an accessibility hit test.
                    .concealed(flow.mode != .shooting)
            }
            .animation(CameraMotion.Panel.animation(to: camera.panel.presentation), value: camera.panel.presentation)
            .animation(FlowMotion.modeChange, value: flow.mode)
            .animation(FlowMotion.markupChange, value: flow.markup.isOpen)
            .disabled(flow.isHandingOver)
            .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
            // The camera's controls keep their places in a right-to-left language, as the stock camera's do, and the
            // review and the drawing mirror theirs in their own layouts. The introduction and the alerts follow the
            // language.
            .environment(\.layoutDirection, .leftToRight)
            .coordinateSpace(.named(LensZoomControl.coordinateSpace))
            .ignoresSafeArea()
            .accessibilityElement(children: .contain)
            .accessibilityAction(.magicTap, takePhotoFromMagicTap)
            .accessibilityAction(.escape, escape)
        }
        // The preview surface and the view state belong to one flow, so a new flow makes a new screen.
        .id(ObjectIdentifier(flow))
        .background(CameraPalette.background.ignoresSafeArea())
        .accessibilityHidden(isOnboarding)
        .onChange(of: flow.camera.panel.presentation) { previous, presentation in
            let tiles = flow.camera.panel.settings
            if let target = FlowFocusTarget.afterPanel(from: previous, to: presentation, tiles: tiles) {
                focus = target
            }
        }
        .onChange(of: flow.markup.isOpen) { _, isOpen in
            focus = .afterDrawing(isOpen: isOpen)
        }
        .onChange(of: isOnboarding) { _, isOnboarding in
            if !isOnboarding {
                focus = .afterIntroduction
            }
        }
        .overlay {
            OnboardingLayer(onboarding: camera.onboarding, offersPhotoLibrary: flow.isLibraryPickerEnabled)
        }
        .modifier(CameraCaptureButtons(isEnabled: flow.acceptsCaptureButtons, capture: camera.capture))
        .modifier(PhotoLibrarySheet(flow: flow))
        .modifier(FlowExitAlert(flow: flow))
        .modifier(FlashUnavailableAlert(settings: camera.settings))
        .background {
            InterfaceOrientationReader(onChange: camera.orientation.interfaceOrientationChanged)
        }
        .environment(\.cameraElementRotation, flow.elementRotation)
        .environment(\.colorScheme, .dark)
        // The library sheet is the system's and follows the interface style, not the environment.
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Whether the introduction covers the flow, so nothing under it is read out.
    private var isOnboarding: Bool {
        flow.camera.onboarding.step != nil
    }

    /// Whether the screen's own controls take the keys of a hardware keyboard: not while the introduction, the sheet of
    /// the photo library or a dialog of the flow stands over them, so that a key never acts on what the user does not
    /// see.
    private var takesKeyboardShortcuts: Bool {
        let isFlashExplained = flow.camera.settings.flash.explanation != nil
        let isDialogShown = flow.exitConfirmation != nil || flow.review.deleteConfirmation != nil || isFlashExplained
        return !isOnboarding && !flow.isLibraryPresented && !isDialogShown
    }

    /// Takes a photo while the hardware buttons would, as the stock camera's Magic Tap does.
    private func takePhotoFromMagicTap() {
        guard flow.acceptsCaptureButtons else { return }
        Task {
            await flow.camera.capture()
        }
    }

    private func escape() {
        let camera = flow.camera
        switch FlowEscape(isDrawing: flow.markup.isOpen, isPanelOpen: camera.panel.isOpen) {
        case .cancelDrawing: flow.markup.cancel()
        case .closePanel: camera.panel.dismiss()
        case .leaveFlow: flow.requestExit()
        }
    }

    /// The layout of the whole screen, under the safe area too.
    private func layout(in proxy: GeometryProxy) -> CameraScreenLayout {
        let camera = flow.camera
        let insets = proxy.safeAreaInsets
        let size = CGSize(
            width: proxy.size.width + insets.leading + insets.trailing,
            height: proxy.size.height + insets.top + insets.bottom
        )
        return CameraScreenLayout(
            size: size,
            safeAreaTop: insets.top,
            aspectRatio: camera.settings.aspectRatio,
            panel: camera.panel.presentation,
            panelTileCount: camera.panel.settings.count,
            interfaceOrientation: camera.orientation.interfaceOrientation
        )
    }
}

/// The camera of the shooting mode: the viewfinder with what lies over it, the top bar, the zoom and the shutter
/// with the buttons beside it.
private struct ShootingMode: View {
    let flow: EmbeddedCameraFlowModel
    let layout: CameraScreenLayout
    let zoomTouch: ZoomTouch
    let focus: AccessibilityFocusState<FlowFocusTarget?>.Binding

    var body: some View {
        let camera = flow.camera
        let pinchInteraction = zoomTouch.pinch
        ZStack(alignment: .topLeading) {
            CameraViewfinder(
                session: camera.session,
                shutter: camera.shutter,
                settings: camera.settings,
                focus: camera.focus,
                layout: layout,
                makePreview: camera.session.makePreview,
                onTap: camera.viewfinderTapped,
                onPressBegan: camera.viewfinderPressBegan,
                onPressEnded: camera.viewfinderPressEnded,
                toggleFocusLock: camera.toggleFocusLock,
                onExposureDragBegan: camera.beginExposureDrag,
                onExposureChanged: camera.changeExposure,
                onExposureDragEnded: camera.endExposureDrag,
                onPinchBegan: {
                    let zooms = flow.mode == .shooting && !flow.isHandingOver && camera.acceptsPinchZoom
                    pinchInteraction.began(isEnabled: zooms)
                },
                onPinchChanged: pinchInteraction.changed,
                onPinchEnded: pinchInteraction.ended,
                onRetry: camera.retry
            )
            FocusReticleView(
                focus: camera.focus,
                settings: camera.settings,
                layout: layout,
                adjustExposure: camera.adjustExposure
            )
            DualCameraCircleView(
                dualCamera: camera.dualCamera,
                layout: layout,
                makePreview: camera.session.makeCirclePreview
            )
            FocusLockBadgeView(focus: camera.focus, dualCamera: camera.dualCamera, layout: layout)
            CameraCountdownView(shutter: camera.shutter, layout: layout)
            CameraTopBar(
                settings: camera.settings,
                dualCamera: camera.dualCamera,
                panel: camera.panel,
                layout: layout,
                toggleDualCamera: camera.toggleDualCamera
            )
            if camera.session.isFlipOffered {
                CameraFlipButton(
                    layout: layout,
                    isEnabled: camera.session.isActive,
                    flipCamera: camera.flipCamera,
                    onTouchDown: camera.flipButtonTouched
                )
            }
            LensZoomControl(zoom: camera.zoom, interaction: zoomTouch.dial, layout: layout)
                .modifier(CaptureOverlayHiding(captureControls: camera.captureControls, panel: camera.panel))
                .modifier(PanelLiftMotion(panel: camera.panel))
            ShutterButton(
                shutter: camera.shutter,
                panel: camera.panel,
                layout: layout,
                isEnabled: flow.canShoot,
                capture: camera.capture
            )
            .modifier(PanelLiftMotion(panel: camera.panel))
            .accessibilityFocused(focus, equals: .shutter)
            ShutterSideButtons(flow: flow, panel: camera.panel, layout: layout, focus: focus)
        }
    }
}
#endif
