//
//  CameraFailureView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// The message in the viewfinder of a camera that does not run, with a button that starts the camera again under a
/// failure that may pass, and a button to the app's page of Settings under a failure the user can lift there.
/// VoiceOver announces the message when it shows, and the text grows with Dynamic Type.
///
/// The look is our own, not the stock one.
struct CameraFailureView: View {
    @Environment(\.flowLocalization) private var localization
    let failure: CameraFailure
    /// Starts the camera again.
    let onRetry: () async -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        let style = CameraMetrics.Failure.self
        VStack(spacing: style.spacing) {
            Text(CameraNoticeText(localization).message(for: failure))
                .font(CameraTypography.message)
                .foregroundStyle(CameraPalette.label)
                .multilineTextAlignment(.center)
            if failure.isRetryable {
                Button(CameraNoticeText(localization).retry) {
                    Task { await onRetry() }
                }
                .font(CameraTypography.failureAction)
                .foregroundStyle(CameraPalette.accent)
                .frame(minHeight: style.actionMinimumHeight)
                .accessibilityIdentifier(CameraIdentifier.retryCamera)
            }
            if failure.isLiftedInSettings, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button(CameraNoticeText(localization).openSettings) {
                    openURL(settingsURL)
                }
                .font(CameraTypography.failureAction)
                .foregroundStyle(CameraPalette.accent)
                .frame(minHeight: style.actionMinimumHeight)
                .accessibilityIdentifier(CameraIdentifier.openSettings)
            }
        }
        .padding(style.padding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .onChange(of: failure, initial: true) { _, failure in
            AccessibilityNotification.Announcement(CameraNoticeText(localization).message(for: failure)).post()
        }
    }
}
#endif
