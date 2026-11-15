//
//  CameraViewfinder.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The preview area. A tap focuses, or closes the control panel when it is open. A long press locks the focus and
/// the exposure, which VoiceOver does with an action. A vertical drag changes the exposure bias, and a pinch zooms. It
/// goes black for an instant when a photo is taken, and shows a message when the camera cannot be used, with the way
/// to Settings when access was denied.
struct CameraViewfinder: View {
    @Environment(\.flowLocalization) private var localization
    let session: CameraSessionModel
    let shutter: ShutterModel
    let settings: PhotoSettingsModel
    let focus: FocusModel
    let layout: CameraScreenLayout
    let makePreview: () -> any CameraPreview
    /// Receives a tap as a point in unit coordinates of the viewfinder, and as the point of the camera's
    /// coordinates it shows.
    let onTap: (CGPoint, CGPoint) -> Void
    /// Receives where a long press began, like a tap.
    let onPressBegan: (CGPoint, CGPoint) -> Void
    /// Receives that the finger of a long press let go.
    let onPressEnded: () -> Void
    /// Locks the focus and the exposure, or ends the lock, as VoiceOver's action on the viewfinder asks.
    let toggleFocusLock: () -> Void
    /// Receives where a vertical drag began, like a tap, and answers whether the drag changes the exposure.
    let onExposureDragBegan: (CGPoint, CGPoint) -> Bool
    let onExposureChanged: (Double) -> Void
    let onExposureDragEnded: () -> Void
    let onPinchBegan: () -> Void
    /// Receives how many times as far apart the fingers are as when the pinch began.
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: () -> Void
    /// Starts the camera again from a failure the user can retry from.
    let onRetry: () async -> Void

    @State private var isBlinking = false
    @State private var exposureDrag: ExposureDrag?

    var body: some View {
        let frame = layout.viewfinder
        ZStack {
            CameraPreviewSurface(
                makePreview: makePreview,
                covers: session.pictureCovers,
                onTap: { point, devicePoint in
                    onTap(unitPoint(of: point, in: frame), devicePoint)
                },
                onLongPressBegan: { point, devicePoint in
                    onPressBegan(unitPoint(of: point, in: frame), devicePoint)
                },
                onLongPressEnded: onPressEnded,
                onDragBegan: { point, devicePoint in
                    beginExposureDrag(at: unitPoint(of: point, in: frame), devicePoint: devicePoint)
                },
                onDragMoved: moveExposureDrag,
                onDragEnded: endExposureDrag,
                onPinchBegan: onPinchBegan,
                onPinchChanged: onPinchChanged,
                onPinchEnded: onPinchEnded
            )
            .accessibilityElement()
            .accessibilityIdentifier(CameraIdentifier.viewfinder)
            .accessibilityLabel(CameraControlText(localization).viewfinder)
            .accessibilityActions {
                if session.isRunning, let adjustments = focus.lockableAdjustments {
                    let name = FocusLockText(localization).action(isLocked: focus.lock != nil, of: adjustments)
                    Button(name, action: toggleFocusLock)
                }
            }
            if let failure = session.failure {
                CameraFailureView(failure: failure, onRetry: onRetry)
            }
            // The blink has no accessibility modifier: any of them, hiding too, makes it an element over what the
            // viewfinder shows.
            CameraPalette.background
                .opacity(isBlinking ? 1 : 0)
                .allowsHitTesting(false)
        }
        .clipped()
        .placed(in: frame)
        .onChange(of: shutter.captureCount) {
            blink()
        }
    }

    /// A point of the viewfinder, in its own coordinates, in unit coordinates of it.
    private func unitPoint(of point: CGPoint, in frame: CGRect) -> CGPoint {
        point.unitPoint(in: CGRect(origin: .zero, size: frame.size))
    }

    private func beginExposureDrag(at unitPoint: CGPoint, devicePoint: CGPoint) {
        guard onExposureDragBegan(unitPoint, devicePoint) else { return }
        exposureDrag = ExposureDrag(startBias: settings.exposureBias, range: settings.availableExposureBiasRange)
    }

    private func moveExposureDrag(translation: CGFloat) {
        guard var drag = exposureDrag else { return }
        let bias = drag.update(translation: translation)
        exposureDrag = drag
        onExposureChanged(bias)
    }

    private func endExposureDrag() {
        exposureDrag = nil
        onExposureDragEnded()
    }

    private func blink() {
        withAnimation(CameraMotion.Capture.blinkIn) {
            isBlinking = true
        } completion: {
            withAnimation(CameraMotion.Capture.blinkOut) {
                isBlinking = false
            }
        }
    }
}
#endif
