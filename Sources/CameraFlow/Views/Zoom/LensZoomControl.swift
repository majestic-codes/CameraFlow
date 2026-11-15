//
//  LensZoomControl.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The lens buttons and the zoom dial that grows out of them. `ZoomDialInteraction` reads the touch on both. For
/// people who reduce motion the dial and its value only fade, and the lens buttons take their new places without
/// sliding.
///
/// To accessibility each lens button selects its lens and adjusts the zoom through `ZoomAdjustment`, and the active
/// one carries the zoom in effect. Focus follows the lens an adjustment makes active, so that the next swipe goes on
/// from there.
struct LensZoomControl: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let zoom: ZoomModel
    /// The touch on the control, which the screen shares with the pinch on the viewfinder.
    let interaction: ZoomDialInteraction
    let layout: CameraScreenLayout

    @Environment(\.cameraElementRotation) private var elementRotation
    /// Whether a finger is on the control. It goes back to false when the touch ends and when the system takes it
    /// away.
    @GestureState private var isTouching = false
    @AccessibilityFocusState private var focusedLens: Int?

    static let coordinateSpace = "PhotoCamera"
    private typealias DialMetrics = CameraMetrics.ZoomDial
    private typealias RowMetrics = CameraMetrics.LensRow

    var body: some View {
        ZStack(alignment: .topLeading) {
            dial
            lensRow
            currentValue
            touchSurface
        }
        .opacity(layout.showsZoomControl ? 1 : 0)
        .allowsHitTesting(layout.showsZoomControl)
        .accessibilityHidden(!layout.showsZoomControl)
        .onChange(of: isTouching) { _, isTouching in
            if !isTouching {
                interaction.touchCancelled()
            }
        }
        .onDisappear {
            interaction.touchCancelled()
            interaction.cancelTimers()
        }
    }

    // MARK: - Dial

    private var dial: some View {
        let disc = layout.zoomDialDisc
        let isOpen = zoom.isDialOpen
        return ZStack(alignment: .top) {
            CameraZoomDialFace(
                zoom: zoom.factor,
                scale: zoom.scale,
                lensFactors: zoom.lenses.map(\.factor),
                markedFactors: zoom.markedFactors,
                labelFactors: zoom.dialLabelFactors,
                focalLengths: focalLengths,
                labelRotation: elementRotation.degrees
            )
            .animation(CameraMotion.Rotation.element, value: elementRotation)
            ZoomDialNeedle()
                .fill(CameraPalette.accent)
                .frame(width: DialMetrics.needleSize.width, height: DialMetrics.needleSize.height)
                .padding(.top, DialMetrics.needleInset)
        }
        .frame(width: disc.width, height: disc.height)
        .animation(isOpen ? CameraMotion.Dial.rise : CameraMotion.Dial.fall) { content in
            content.scaleEffect(isOpen || reduceMotion ? 1 : DialMetrics.closedScale)
        }
        .compositingGroup()
        .animation(isOpen ? CameraMotion.Dial.fadeIn : CameraMotion.Dial.fadeOut) { content in
            content.opacity(isOpen ? 1 : 0)
        }
        .accessibilityHidden(true)
        .offset(x: disc.minX, y: disc.minY)
    }

    private var focalLengths: [CGFloat: Int] {
        var focalLengthsByFactor: [CGFloat: Int] = [:]
        for lens in zoom.lenses {
            if let focalLength = lens.focalLength {
                focalLengthsByFactor[lens.factor] = focalLength
            }
        }
        return focalLengthsByFactor
    }

    private func stepZoom(_ direction: AccessibilityAdjustmentDirection) {
        let adjustment = ZoomAdjustment(lensFactors: zoom.lenses.map(\.factor), range: zoom.scale.range)
        let step: ZoomAdjustment.Direction = direction == .increment ? .increment : .decrement
        guard let factor = adjustment.factor(from: zoom.factor, toward: step) else { return }
        let activeIndex = zoom.activeLensIndex
        zoom.setZoom(factor)
        if focusedLens != nil, zoom.activeLensIndex != activeIndex {
            focusedLens = zoom.activeLensIndex
        }
    }

    // MARK: - Lens row

    private var lensRow: some View {
        let row = layout.lensRow
        let rowLayout = lensRowLayout
        let isOpen = zoom.isDialOpen
        return ZStack {
            ForEach(Array(zoom.lenses.enumerated()), id: \.element.factor) { index, lens in
                let isActive = index == rowLayout.activeIndex
                let title = isActive
                    ? ZoomFactorTitle.current(zoom.factor, localization: localization)
                    : ZoomFactorTitle.lens(lens.factor, locale: localization.locale)
                LensZoomButton(
                    title: title,
                    isActive: isActive,
                    isPressed: interaction.pressedLensIndex == index
                )
                .animation(reduceMotion ? nil : CameraMotion.Lens.slide) { content in
                    let shift = CGSize(width: rowLayout.offset(of: index), height: 0)
                    content.modifier(LensZoomShift(translation: shift))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(CameraIdentifier.lens(lens.factor))
                .accessibilityLabel(CameraControlText(localization).lens(lens.factor))
                .accessibilityValue(isActive ? CameraControlText(localization).zoomValue(zoom.factor) : "")
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                .accessibilityInputLabels([title, CameraControlText(localization).lens(lens.factor)])
                .accessibilityAction { zoom.selectLens(at: index) }
                .accessibilityAdjustableAction(stepZoom)
                .accessibilityFocused($focusedLens, equals: index)
                .showsLargeContent(title)
            }
        }
        .frame(width: row.width, height: row.height)
        .compositingGroup()
        .animation(isOpen ? CameraMotion.Dial.fadeIn : CameraMotion.Dial.fadeOut) { content in
            content.opacity(isOpen ? 0 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CameraIdentifier.lensRow)
        .accessibilityHidden(isOpen)
        .offset(x: row.minX, y: row.minY)
    }

    /// The current zoom of the open dial. It fades in over the active lens button and rises to the needle, or fades
    /// in at the needle for people who reduce motion.
    private var currentValue: some View {
        let diameter = RowMetrics.buttonDiameter
        let row = layout.lensRow
        let isOpen = zoom.isDialOpen
        return LensZoomTitle(title: ZoomFactorTitle.current(zoom.factor, localization: localization), isActive: true)
            .animation(isOpen ? CameraMotion.Dial.rise : CameraMotion.Dial.fall) { content in
                let isRisen = isOpen || reduceMotion
                let rise = CGSize(width: 0, height: isRisen ? -DialMetrics.closedOffset : 0)
                content.modifier(LensZoomShift(translation: rise))
            }
            .compositingGroup()
            .animation(isOpen ? CameraMotion.Dial.fadeIn : CameraMotion.Dial.valueFadeOut) { content in
                content.opacity(isOpen ? 1 : 0)
            }
            .accessibilityHidden(true)
            .offset(x: row.midX - diameter / 2, y: row.midY - diameter / 2)
    }

    /// One surface takes every touch: the dial strip while the dial is open, otherwise the row together with
    /// every button wherever the row has slid. While the dial is open the surface is the dial to accessibility.
    private var touchSurface: some View {
        let isOpen = zoom.isDialOpen
        let frame = isOpen ? layout.zoomDial : lensRowLayout.touchFrame
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: frame.width, height: frame.height)
            .gesture(dialGesture)
            .accessibilityElement()
            .accessibilityIdentifier(CameraIdentifier.zoomDial)
            .accessibilityLabel(CameraControlText(localization).zoom)
            .accessibilityAdjustableAction(stepZoom)
            .accessibilityValue(CameraControlText(localization).zoomValue(zoom.factor))
            .accessibilityHidden(!isOpen)
            .offset(x: frame.minX, y: frame.minY)
    }

    /// Where the lens buttons stand now: the active one in the middle of the row, the others a pitch apart.
    private var lensRowLayout: LensRowLayout {
        LensRowLayout(row: layout.lensRow, lensCount: zoom.lenses.count, activeIndex: zoom.activeLensIndex ?? 0)
    }
}

// MARK: - Touch

private extension LensZoomControl {
    var dialGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
            .updating($isTouching) { _, isTouching, _ in
                isTouching = true
            }
            .onChanged { drag in
                let time = drag.time.timeIntervalSinceReferenceDate
                interaction.touchChanged(to: drag.location, from: drag.startLocation, time: time, in: layout)
            }
            .onEnded { drag in
                interaction.touchEnded(at: drag.location, from: drag.startLocation, in: layout)
            }
    }
}
#endif
