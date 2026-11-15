//
//  CameraTopBar.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The row above the viewfinder, centred by its count: the controls Flash, Live, the second camera's circle and
/// Save, each only when the app lets the user change it, then an indicator for every setting the user has moved
/// off its default (`PhotoSettingsModel.topBarItems`). A control is yellow while its feature is on, Flash while the
/// next photo fires it, and an indicator always, since it stands for a change.
///
/// A tap on Flash cycles its mode, or says why the flash cannot fire while it shows the flash unavailable. A tap on
/// Live or Save toggles it and a tap on the circle's indicator turns the circle on or off. A tap on the indicator of a
/// changed setting opens its sub-panel. An indicator is dimmed and inert while it cannot be used.
///
/// The row is one scroll view whether it fits the strip before the flip button or not, so an indicator keeps its
/// identity and animates when the row starts or stops scrolling. A row that fits stands centred and does not
/// scroll. A row that is wider than the strip scrolls and snaps to the slots. An item that nears an edge of the
/// strip shrinks and fades away, so that no hard edge cuts it. An indicator that appears off the strip is scrolled
/// into view.
struct CameraTopBar: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiatesWithoutColor
    let settings: PhotoSettingsModel
    let dualCamera: DualCameraModel
    let panel: ControlPanelModel
    let layout: CameraScreenLayout
    let toggleDualCamera: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: Reveal?

    /// The request to bring an item into view. The serial tells two requests for the same item apart.
    private struct Reveal: Equatable {
        let setting: CameraSetting
        let serial: Int
    }

    var body: some View {
        let items = settings.topBarItems
        row(items)
            .onChange(of: items) { previousItems, items in
                guard let setting = TopBarReveal.newestItem(in: items, since: previousItems) else { return }
                reveal = Reveal(setting: setting, serial: (reveal?.serial ?? 0) + 1)
            }
    }

    /// The items side by side at the pitch of the slots, centred in the strip while they fit it. The row takes the
    /// strip grown to the squares the items take a touch in.
    private func row(_ items: [CameraSetting]) -> some View {
        let strip = layout.topBarTouchStrip
        let overflows = layout.topBarOverflows(itemCount: items.count)
        let edgeScale = reduceMotion ? 1 : CameraMetrics.TopBar.edgeScale
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: CameraMetrics.TopBar.pitch - CameraMetrics.TopBar.touchSize) {
                    ForEach(items, id: \.self) { setting in
                        indicator(for: setting)
                            .transition(appearTransition)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .opacity(1 - abs(phase.value))
                                    .scaleEffect(1 - (1 - edgeScale) * abs(phase.value))
                            }
                    }
                }
                .scrollTargetLayout()
                .frame(minWidth: strip.width)
                .animation(reduceMotion ? nil : CameraMotion.TopBar.change, value: items)
            }
            .scrollDisabled(!overflows)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .frame(width: strip.width, height: strip.height)
            .offset(x: strip.minX, y: strip.minY)
            .onChange(of: reveal) { _, reveal in
                guard let reveal else { return }
                withAnimation(reduceMotion ? nil : CameraMotion.TopBar.change) {
                    proxy.scrollTo(reveal.setting, anchor: .trailing)
                }
            }
        }
    }

    /// An indicator grows in as it fades in, while the row slides to centre the items again. For people who reduce
    /// motion it only fades, and the other items take their places at once.
    private var appearTransition: AnyTransition {
        guard !reduceMotion else { return .opacity.animation(CameraMotion.TopBar.change) }
        return .opacity.combined(with: .scale(scale: CameraMotion.TopBar.indicatorAppearScale))
    }

    @ViewBuilder
    private func indicator(for setting: CameraSetting) -> some View {
        let speech = CameraSettingSpeech(localization)
        let name = speech.name(of: setting)
        switch setting {
        case .flash:
            let flashMode = settings.effectiveFlashMode
            indicator(isOn: settings.isFlashLit, isEnabled: settings.isFlashSelectable, name: name) {
                settings.flashIndicatorTapped()
            } glyph: {
                CameraGlyphView(glyph: flashGlyph(flashMode))
            }
            .accessibilityIdentifier(CameraIdentifier.flash)
            .accessibilityValue(flashValue(flashMode))
            .accessibilityHint(flashHint)
        case .live:
            let isOn = settings.isLivePhotoInEffect
            indicator(isOn: isOn, isEnabled: settings.isLivePhotoSelectable, name: name) {
                settings.toggleLivePhoto()
            } glyph: {
                CameraGlyphView(glyph: CameraGlyph(isLivePhotoOn: isOn))
            }
            .accessibilityIdentifier(CameraIdentifier.livePhoto)
            .accessibilityValue(speech.switchState(isOn: isOn))
        case .dualCamera:
            indicator(isOn: dualCamera.isOn, isEnabled: dualCamera.isToggleEnabled, name: name) {
                Task { await toggleDualCamera() }
            } glyph: {
                dualCameraGlyph
            }
            .accessibilityIdentifier(CameraIdentifier.dualCamera)
            .accessibilityValue(speech.switchState(isOn: dualCamera.isOn))
        case .librarySave:
            let isOn = settings.isLibrarySavingOn
            indicator(isOn: isOn, isEnabled: true, name: name) {
                Task { await settings.toggleLibrarySaving() }
            } glyph: {
                librarySaveGlyph(isOn: isOn)
            }
            .accessibilityIdentifier(CameraIdentifier.librarySave)
            .accessibilityValue(speech.switchState(isOn: isOn))
        case .aspect, .timer, .exposure, .format:
            indicator(isOn: true, isEnabled: true, name: name) {
                panel.showSubPanel(setting)
            } glyph: {
                changedSettingFace(setting)
            }
            .accessibilityIdentifier(CameraIdentifier.topBarIndicator(setting))
            .accessibilityValue(speech.value(of: setting, in: settings))
            .accessibilityHint(CameraControlText(localization).changedSettingHint)
            .accessibilityInputLabels(speech.indicatorInputLabels(of: setting, in: settings))
        }
    }

    /// The glyph of Flash: the mode the camera takes, Auto outlined while it would not fire for people who
    /// differentiate without colour, or the flash unavailable while it cannot fire.
    private func flashGlyph(_ flashMode: CameraFlowFlashMode) -> CameraGlyph {
        guard settings.flashUnavailability == nil else { return .flashUnavailable }
        let isLit = settings.isFlashLit
        return CameraGlyph(flashMode: flashMode, isLit: isLit, differentiatesWithoutColor: differentiatesWithoutColor)
    }

    /// What VoiceOver reads as the value of Flash: the mode the camera takes, or that the flash is disabled while it
    /// cannot fire.
    private func flashValue(_ flashMode: CameraFlowFlashMode) -> String {
        guard settings.flashUnavailability != nil else {
            return CameraSettingSpeech(localization).flashMode(flashMode)
        }
        return FlashUnavailableText(localization).title
    }

    /// What VoiceOver reads as the hint of Flash: that a tap changes the mode, or why the flash cannot fire, which a
    /// tap says.
    private var flashHint: String {
        guard let unavailability = settings.flashUnavailability else {
            return CameraControlText(localization).flashHint
        }
        return FlashUnavailableText(localization).message(for: unavailability, on: .current)
    }

    /// The glyph of the circle's toggle. With Differentiate Without Color on, the empty frame tells the circle off
    /// from on, as its tile does, where the colour alone cannot.
    private var dualCameraGlyph: some View {
        DualCameraGlyphView(hasCircle: dualCamera.isOn || !differentiatesWithoutColor)
    }

    /// The glyph of Save. With Differentiate Without Color on it is dimmed while saving is off, as its tile is.
    private func librarySaveGlyph(isOn: Bool) -> some View {
        FlowSymbolView(symbol: .librarySave, pointSize: CameraMetrics.Symbol.topBarPointSize, weight: .regular)
            .opacity(isOn || !differentiatesWithoutColor ? 1 : CameraPalette.unavailableOpacity)
    }

    /// The face of a changed setting: its state glyph for the aspect ratio and the timer, the value as text for
    /// the exposure bias, the format and a quality below the high one, as the stock top bar writes "HDR".
    @ViewBuilder
    private func changedSettingFace(_ setting: CameraSetting) -> some View {
        switch setting {
        case .aspect:
            CameraGlyphView(glyph: CameraGlyph(aspectRatio: settings.aspectRatio), placement: .topBar)
        case .timer:
            CameraGlyphView(glyph: CameraGlyph(timer: settings.timer), placement: .topBar)
        case .exposure:
            Text(CameraSettingText(localization).signedStops(settings.exposureBias))
                .font(CameraTypography.topBarValue)
        case .format:
            let format = settings.effectivePhotoFormat
            Text(CameraSettingText(localization).formatMark(format: format, quality: settings.photoQuality))
                .font(CameraTypography.topBarValue)
        case .flash, .live, .dualCamera, .librarySave:
            EmptyView()
        }
    }

    /// An item of the row, labelled with the name of its setting, which the Large Content Viewer shows with its glyph
    /// as the bar does not grow with the text size. It takes a touch in the square a finger needs around the drawn
    /// one.
    private func indicator(
        isOn: Bool,
        isEnabled: Bool,
        name: String,
        action: @escaping () -> Void,
        @ViewBuilder glyph: () -> some View
    ) -> some View {
        let face = glyph()
        let metrics = CameraMetrics.TopBar.self
        return Button(action: action) {
            face
                .foregroundStyle(isOn ? CameraPalette.accent : CameraPalette.label)
                .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                .rotatesWithDevice()
                .frame(width: metrics.touchSize, height: metrics.touchSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : CameraPalette.unavailableOpacity)
        .disabled(!isEnabled)
        .accessibilityLabel(name)
        .showsLargeContent(name) {
            face
        }
    }
}
#endif
