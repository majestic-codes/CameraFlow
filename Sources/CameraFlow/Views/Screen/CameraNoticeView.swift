//
//  CameraNoticeView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A small capsule at the top of the viewfinder, or below the front camera's circle while it shows, that says why
/// the camera is paused, why a photo failed or what the photo library could not add. A notice too long for one line
/// wraps, to two lines at most at the default text size and three at the largest, and the capsule grows down from
/// its row. VoiceOver announces each new notice, and its text grows with Dynamic Type up to the largest size short of
/// the accessibility sizes.
///
/// The look is our own, not the stock one.
struct CameraNoticeView: View {
    /// The line to show, nil for none.
    let notice: String?
    /// The row the capsule hangs from, centred across it.
    let frame: CGRect

    var body: some View {
        ZStack(alignment: .top) {
            if let notice {
                NoticeCapsule(text: notice)
                    .transition(.opacity)
                    .accessibilityIdentifier(CameraIdentifier.notice)
            }
        }
        .animation(.easeInOut(duration: CameraMotion.Notice.duration), value: notice)
        .allowsHitTesting(false)
        .frame(width: frame.width, height: frame.height, alignment: .top)
        .offset(x: frame.minX, y: frame.minY)
        .onChange(of: notice) { _, notice in
            if let notice {
                AccessibilityNotification.Announcement(notice).post()
            }
        }
    }
}

/// The capsule with the text of a notice, whose size follows the text size of the capsule's surroundings, up to
/// `CameraMetrics.Notice.largestTextScale` times its size at the default one. A text too long for one line takes the
/// lines it needs, and the capsule grows down.
private struct NoticeCapsule: View {
    let text: String

    @ScaledMetric(relativeTo: .subheadline) private var textSize = CameraTypography.noticeSize

    var body: some View {
        let style = CameraMetrics.Notice.self
        let size = min(textSize, CameraTypography.noticeSize * style.largestTextScale)
        Text(text)
            .font(CameraTypography.notice(size: size))
            .foregroundStyle(CameraPalette.label)
            .lineLimit(style.maximumLineCount)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .frame(minHeight: style.height)
            .background(
                RoundedRectangle(cornerRadius: style.height / 2, style: .continuous)
                    .fill(CameraPalette.background.opacity(style.backgroundOpacity))
            )
    }
}
#endif
