//
//  FocusLockBadgeView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The stock "AE/AF LOCK" badge while the focus and the exposure are locked, "AE LOCK" or "AF LOCK" on a camera that
/// locks one of the two: a yellow plate in the stock badge tray at the top of the viewfinder, or along the edge that is
/// up while the phone is held in landscape. The text is cut out of the plate and darkens the picture behind it, at the
/// stock badge's sizes for the text size in effect. VoiceOver announces the lock as it takes and as it ends.
struct FocusLockBadgeView: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.cameraElementRotation) private var rotation
    @Environment(\.dynamicTypeSize) private var textSize
    let focus: FocusModel
    let dualCamera: DualCameraModel
    let layout: CameraScreenLayout

    var body: some View {
        let isLocked = focus.lock == .locked
        ZStack(alignment: .topLeading) {
            if isLocked, let adjustments = focus.lockableAdjustments {
                ZStack(alignment: .topLeading) {
                    placedBadge(for: adjustments)
                        .id(rotation.orientation)
                        .transition(CameraMotion.FocusLock.relocation)
                }
                .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
                .transition(.opacity)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .animation(CameraMotion.FocusLock.badge, value: isLocked)
        .allowsHitTesting(false)
        .onChange(of: isLocked) { _, isLocked in
            guard let adjustments = focus.lockableAdjustments else { return }
            let announcement = FocusLockText(localization).announcement(isLocked: isLocked, of: adjustments)
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    /// The badge of what the lock holds at its place for the way the phone is held, turned upright for the user.
    private func placedBadge(for adjustments: LockableAdjustments) -> some View {
        let text = FocusLockText(localization)
        let badge = text.badge(for: adjustments)
        let style = CameraTextStyle.focusLockBadge(size: CameraTextStyle.focusLockBadgeSize(at: textSize))
        let tracking = LetterTracking(localization)
        let textLength = style.width(of: badge, tracking: tracking)
        let placement = layout.focusLockBadge(
            length: textLength + 2 * CameraMetrics.FocusLockBadge.textInset,
            isDualCameraCircleShown: dualCamera.isOn,
            elementOrientation: rotation.orientation
        )
        return FocusLockPlate(
            text: badge,
            font: CameraTypography.font(style),
            tracking: tracking.amount(style.tracking),
            length: placement.length
        )
        .rotationEffect(.degrees(placement.angle))
        .position(placement.center)
        .accessibilityElement()
        .accessibilityLabel(text.announcement(isLocked: true, of: adjustments))
        .accessibilityIdentifier(CameraIdentifier.focusLock)
    }
}

/// The plate of the badge with its text cut out of it and shaded.
private struct FocusLockPlate: View {
    let text: String
    let font: Font
    let tracking: CGFloat
    /// The length of the plate, which a text too long for it is set smaller to fit.
    let length: CGFloat

    private typealias Metrics = CameraMetrics.FocusLockBadge

    var body: some View {
        label
            .foregroundStyle(CameraPalette.focusLockBadgeText)
            .padding(.vertical, Metrics.verticalPadding)
            .frame(width: length)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(CameraPalette.focusLockBadge)
                    .overlay {
                        label.blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
    }

    /// The text in the room the plate leaves it, laid out alike for the cut and for its shade.
    private var label: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .lineLimit(1)
            .minimumScaleFactor(Metrics.minimumTextScale)
            .frame(width: max(length - 2 * Metrics.textInset, 0))
    }
}
#endif
