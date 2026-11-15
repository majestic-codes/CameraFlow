//
//  FlowModeSwitch.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The switch between the shooting and the review in the slot of the stock mode picker: a glass capsule with a
/// thumb under the selected mode. The thumb follows a finger and settles on the nearer mode, and the label under
/// it turns to the accent colour as far as the thumb covers it. A drag the system takes away settles the thumb back
/// on the mode the flow is in. The review is dimmed and inert until it has a photo to show, and carries the count of
/// the set.
struct FlowModeSwitch: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let photoSet: PhotoSetModel
    let layout: ModeSwitchLayout
    let landedCaptureCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the thumb is from the shooting to the review, 0...1 and a little beyond under a pull.
    @State private var position: CGFloat
    @State private var stretch: CGFloat = 0
    /// Whether a finger is on the switch. It goes back to false when the drag ends and when the system takes it
    /// away.
    @GestureState private var isTouched = false
    /// Whether the thumb follows a finger that has not let go yet, which a drag the system takes away leaves true.
    @State private var isDragging = false

    init(flow: EmbeddedCameraFlowModel, photoSet: PhotoSetModel, layout: ModeSwitchLayout, landedCaptureCount: Int) {
        self.flow = flow
        self.photoSet = photoSet
        self.layout = layout
        self.landedCaptureCount = landedCaptureCount
        _position = State(initialValue: flow.mode == .review ? 1 : 0)
    }

    /// The widths of the two labels in the current language.
    static func labelWidths(in localization: FlowLocalization) -> ModeLabelWidths {
        let text = FlowText(localization)
        let tracking = LetterTracking(localization)
        return ModeLabelWidths(
            shooting: CameraTypography.modeLabelWidth(text.modeLabel(.shooting), tracking: tracking),
            review: CameraTypography.modeLabelWidth(text.modeLabel(.review), tracking: tracking)
        )
    }

    private var tracking: ModeSwitchTracking {
        ModeSwitchTracking(travel: layout.travel, canReachReview: flow.canShowReview || flow.mode == .review)
    }

    var body: some View {
        let local = layout.insideCapsule
        let thumb = local.thumb(at: position)
        ZStack(alignment: .topLeading) {
            Color.clear
                .cameraGlass(.control, in: Capsule())
                .accessibilityHidden(true)
            ModeSwitchLabels(layout: local, color: CameraPalette.label, isReviewAvailable: flow.canShowReview)
            ModeSwitchThumb(frame: thumb, stretch: stretch)
            ModeSwitchLabels(layout: local, color: CameraPalette.accent, isReviewAvailable: flow.canShowReview)
                .mask(alignment: .topLeading) {
                    Capsule().thumbPlaced(thumb, stretch: stretch)
                }
            segment(.shooting, in: local)
            segment(.review, in: local)
            ModeSwitchBadge(photoSet: photoSet, landedCaptureCount: landedCaptureCount)
                .placed(in: local.badge)
        }
        .frame(width: local.frame.width, height: local.frame.height, alignment: .topLeading)
        .contentShape(Capsule())
        .gesture(drag)
        .placed(in: layout.frame)
        .onChange(of: flow.mode) {
            move(to: flow.mode, velocity: 0)
        }
        .onChange(of: isTouched) {
            if isTouched {
                flow.modeSwitchTouched()
            } else if isDragging {
                // A drag the system took away settles the thumb back on the mode, which stays as it was.
                isDragging = false
                move(to: flow.mode, velocity: 0)
            }
        }
    }

    /// The part of the switch that VoiceOver and the tests see: the pill of a mode, which a double tap or an
    /// adjustment moves the thumb to.
    private func segment(_ mode: CameraFlowMode, in local: ModeSwitchLayout) -> some View {
        let isSelected = flow.mode == mode
        return Button {
            choose(mode)
        } label: {
            Color.clear
        }
        .buttonStyle(.plain)
        .allowsHitTesting(false)
        .disabled(mode == .review && !flow.canShowReview)
        .accessibilityIdentifier(FlowIdentifier.mode(mode))
        .accessibilityLabel(FlowText(localization).modeName(mode))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: choose(.review)
            case .decrement: choose(.shooting)
            @unknown default: break
            }
        }
        .placed(in: local.segment(mode))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouched) { _, isTouched, _ in
                isTouched = true
            }
            .onChanged { value in
                isDragging = true
                position = tracking.progress(from: flow.mode, translation: value.translation.width)
                let newStretch = reduceMotion ? 0 : ModeSwitchTracking.stretch(velocity: value.velocity.width)
                withAnimation(FlowMotion.modeThumbStretch) {
                    stretch = newStretch
                }
            }
            .onEnded { value in
                isDragging = false
                release(value)
            }
    }

    /// Settles the thumb on the mode the finger asked for and changes the mode of the flow with it.
    private func release(_ value: DragGesture.Value) {
        let tracking = tracking
        let translation = value.translation.width
        let isTap = tracking.isTap(translation: value.translation)
        let requested = isTap
            ? layout.insideCapsule.mode(atOffset: value.startLocation.x)
            : tracking.proposedMode(from: flow.mode, translation: translation, velocity: value.velocity.width)
        let velocity = isTap ? 0 : value.velocity.width
        move(to: tracking.reachable(requested), velocity: velocity)
        choose(requested)
    }

    private func choose(_ mode: CameraFlowMode) {
        Task {
            await flow.select(mode)
        }
    }

    /// Animates the thumb to a mode and relaxes the stretch. `velocity` is the speed of the finger that let go.
    private func move(to mode: CameraFlowMode, velocity: CGFloat) {
        let tracking = tracking
        let target = tracking.restingProgress(of: mode)
        guard position != target || stretch != 0 else { return }
        let settleVelocity = tracking.settleVelocity(from: position, to: mode, fingerVelocity: velocity)
        let animation = reduceMotion
            ? FlowMotion.modeThumbSettleReduced
            : FlowMotion.modeThumbSettle(initialVelocity: settleVelocity)
        withAnimation(animation) {
            position = target
            stretch = 0
        }
    }
}
#endif
