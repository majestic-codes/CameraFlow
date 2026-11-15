//
//  ModeSwitchBadge.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The count of the set on the review segment, in a circle of the accent colour. A spinner takes the place of the
/// count while picks from the photo library load. The circle bumps when the copy of a fresh photo lands in it,
/// except for people who reduce motion, for whom it also comes and goes with a fade instead of a scale. VoiceOver
/// announces the count whenever the set grows.
struct ModeSwitchBadge: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    let photoSet: PhotoSetModel
    let landedCaptureCount: Int

    /// What the circle shows.
    private enum Face: Equatable {
        case loading
        case count(Int)

        var identifier: String {
            switch self {
            case .loading: FlowIdentifier.modeImporting
            case .count: FlowIdentifier.modeBadge
            }
        }

        func label(in localization: FlowLocalization) -> String {
            switch self {
            case .loading: FlowText(localization).loadingPhotos
            case .count: FlowText(localization).photosInSet
            }
        }

        func value(in localization: FlowLocalization) -> String {
            switch self {
            case .loading: ""
            case let .count(count): count.formatted(.number.locale(localization.locale))
            }
        }
    }

    /// The face of the circle, nil while there is no circle: an empty set with nothing on its way.
    private var face: Face? {
        if photoSet.isImporting {
            return .loading
        }
        return photoSet.isEmpty ? nil : .count(photoSet.count)
    }

    var body: some View {
        let diameter = FlowMetrics.ModeSwitch.badgeDiameter
        let face = face
        let bumpTrigger = reducesMotion ? 0 : landedCaptureCount
        ZStack {
            if let face {
                picture(of: face)
                    .frame(width: diameter, height: diameter)
                    .background(Circle().fill(CameraPalette.accent))
                    .accessibilityElement()
                    .accessibilityIdentifier(face.identifier)
                    .accessibilityLabel(face.label(in: localization))
                    .accessibilityValue(face.value(in: localization))
                    .transition(reducesMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .phaseAnimator([1, FlowMotion.badgeBumpScale], trigger: bumpTrigger) { badge, scale in
            badge.scaleEffect(scale)
        } animation: { _ in
            FlowMotion.badgeBump
        }
        .animation(FlowMotion.availability, value: face)
        .allowsHitTesting(false)
        .onChange(of: photoSet.count) { previousCount, count in
            guard count > previousCount else { return }
            let announcement = FlowText(localization).photosInSetAnnouncement(count)
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    @ViewBuilder
    private func picture(of face: Face) -> some View {
        switch face {
        case .loading:
            ProgressView()
                .controlSize(.mini)
                .tint(CameraPalette.onAccent)
        case let .count(count):
            Text(count, format: .number)
                .font(CameraTypography.badgeCount)
                .foregroundStyle(CameraPalette.onAccent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 2)
                .rotatesWithDevice()
        }
    }
}
#endif
