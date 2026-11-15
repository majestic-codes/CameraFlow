//
//  CameraCountdownView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Seconds left on the self-timer, large in the middle of the viewfinder. Each new second grows in as the last
/// one shrinks away, or fades in as the last one fades out for people who reduce motion, and VoiceOver announces it.
///
/// The look is our own: the stock countdown was never recorded.
struct CameraCountdownView: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shutter: ShutterModel
    let layout: CameraScreenLayout

    var body: some View {
        let style = CameraMetrics.Countdown.self
        ZStack {
            if let seconds = shutter.countdownSeconds {
                Text(CameraSettingText(localization).countdown(seconds))
                    .font(CameraTypography.countdown)
                    .foregroundStyle(CameraPalette.label)
                    .shadow(color: CameraPalette.countdownShadow, radius: style.shadowRadius)
                    .rotatesWithDevice()
                    .id(seconds)
                    .transition(secondTransition)
                    .accessibilityIdentifier(CameraIdentifier.countdown)
                    .accessibilityLabel(CameraSettingSpeech(localization).name(of: .timer))
                    .accessibilityValue(CameraSettingText(localization).countdown(seconds))
            }
        }
        .animation(.easeOut(duration: CameraMotion.Countdown.tickDuration), value: shutter.countdownSeconds)
        .allowsHitTesting(false)
        .placed(in: layout.countdown)
        .onChange(of: shutter.countdownSeconds) { _, seconds in
            if let seconds {
                AccessibilityNotification.Announcement(seconds.formatted(.number.locale(localization.locale))).post()
            }
        }
    }

    private var secondTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let style = CameraMetrics.Countdown.self
        return .asymmetric(
            insertion: .scale(scale: style.enteringScale).combined(with: .opacity),
            removal: .scale(scale: style.leavingScale).combined(with: .opacity)
        )
    }
}
#endif
