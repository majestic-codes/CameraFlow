//
//  FocusReticleView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The yellow focus square with the exposure slider beside it, shown where the viewfinder was tapped.
///
/// The slider is a one point rail with the sun on it. The sun sits at the height of the exposure bias and the rail
/// shows while the bias changes. On a tap the whole reticle grows from twice its size onto the point while it fades
/// in and the square pulses while the camera focuses. After about four seconds it dims; the model clears it later.
///
/// A long press fades in a larger square without the sun, which pulses until the focus and the exposure lock and
/// then bounces twice. As the finger lets go the square shrinks to its size, the sun comes back, and the reticle dims
/// shortly after. A locked reticle stays until the lock ends.
struct FocusReticleView: View {
    let focus: FocusModel
    let settings: PhotoSettingsModel
    let layout: CameraScreenLayout
    /// Moves the exposure bias by a step from the adjustable element of the sun, which keeps the reticle on screen.
    let adjustExposure: (Double) -> Void

    private typealias Metrics = CameraMetrics.FocusReticle

    var body: some View {
        let viewfinder = layout.viewfinder
        ZStack(alignment: .topLeading) {
            if let reticle = focus.reticle {
                let center = reticle.location.scaled(fromUnitTo: viewfinder)
                let lock = FocusReticleMark.Lock(isPressing: focus.isPressing, phase: focus.lock)
                let centerX = reticle.location.x * viewfinder.width
                let side = FocusReticleLayout.side(reticleCenterX: centerX, viewfinderWidth: viewfinder.width)
                FocusReticleMark(
                    settings: settings,
                    adjustExposure: adjustExposure,
                    kind: reticle.kind,
                    lock: lock,
                    isAdjusting: focus.isAdjustingExposure,
                    side: side
                )
                .offset(x: center.x - Metrics.side / 2, y: center.y - Metrics.side / 2)
                .id(reticle.identifier)
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .animation(CameraMotion.Reticle.fade, value: focus.reticle)
        .allowsHitTesting(false)
    }
}

/// The square, the rail and the sun with the appear choreography.
private struct FocusReticleMark: View {
    /// What the AE/AF Lock does to the reticle: the finger of its press, and how far the lock has got.
    struct Lock: Equatable {
        let isPressing: Bool
        let phase: FocusLock?

        /// The square pulses while the camera focuses and exposes for the lock.
        var isSettling: Bool {
            phase == .pressing || phase == .settling
        }
    }

    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel
    let adjustExposure: (Double) -> Void
    let kind: FocusReticle.Kind
    let lock: Lock
    let isAdjusting: Bool
    let side: FocusReticleLayout.Side

    @State private var hasSettled = false
    @State private var isDimmed = false
    @State private var isRailVisible = false
    /// Counts the requests to fade the rail. A new one restarts the wait, and the mark leaving the screen ends it.
    @State private var railFadeRequest = 0
    /// Counts the locks that took while the mark showed, each of which bounces the mark.
    @State private var lockBounceRequest = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Metrics = CameraMetrics.FocusReticle
    private static let half = CameraMotion.Reticle.pulseHalfCycle

    var body: some View {
        ZStack(alignment: .topLeading) {
            square
            Group {
                rail
                exposureSun
            }
            .opacity(lock.isPressing ? 0 : 1)
            .animation(CameraMotion.FocusLock.release, value: lock.isPressing)
            .accessibilityHidden(lock.isPressing)
        }
        .frame(width: Metrics.side, height: Metrics.side, alignment: .topLeading)
        .keyframeAnimator(initialValue: 1.0, trigger: lockBounceRequest) { mark, scale in
            mark.scaleEffect(scale)
        } keyframes: { _ in
            lockBounce
        }
        .scaleEffect(hasSettled || reduceMotion || kind == .press ? 1 : Metrics.appearScale)
        .animation(CameraMotion.Reticle.settle, value: hasSettled)
        .opacity(hasSettled ? (isDimmed ? Metrics.dimmedOpacity : 1) : 0)
        .animation(CameraMotion.Reticle.fade, value: hasSettled)
        .animation(CameraMotion.Reticle.fade, value: isDimmed)
        .task(id: isAdjusting || lock.isPressing) {
            hasSettled = true
            guard !isAdjusting, !lock.isPressing else {
                isDimmed = false
                return
            }
            do {
                try await Task.sleep(for: brightDuration)
            } catch {
                return
            }
            isDimmed = true
        }
        .onChange(of: lock.phase) { _, phase in
            if phase == .locked, !reduceMotion {
                lockBounceRequest += 1
            }
        }
        .onChange(of: settings.exposureBias) {
            isRailVisible = true
            railFadeRequest += 1
        }
        .onChange(of: isAdjusting) {
            if isRailVisible {
                railFadeRequest += 1
            }
        }
        .task(id: railFadeRequest) {
            await fadeRailAfterHold()
        }
    }

    /// How long the reticle stays bright: about four seconds after a tap, and a moment after the finger of a long
    /// press let go.
    private var brightDuration: Duration {
        switch kind {
        case .tap: CameraMotion.Reticle.fullBrightnessDuration
        case .press: CameraMotion.FocusLock.releaseDimDelay
        }
    }

    /// The side of the square: larger while the finger of a long press holds.
    private var squareSide: CGFloat {
        lock.isPressing ? Metrics.side * CameraMetrics.FocusLock.pressedReticleScale : Metrics.side
    }

    /// The square grows by the stock width on each side and settles back, twice, as the lock takes.
    private var lockBounce: some Keyframes<Double> {
        let expanded = Double((squareSide + 2 * CameraMetrics.FocusLock.lockBounceExpansion) / squareSide)
        let duration = CameraMotion.FocusLock.bounceDuration
        let curve = CameraMotion.FocusLock.bounceCurve
        return KeyframeTrack {
            MoveKeyframe(expanded)
            LinearKeyframe(1, duration: duration, timingCurve: curve)
            MoveKeyframe(expanded)
            LinearKeyframe(1, duration: duration, timingCurve: curve)
        }
    }

    private var square: some View {
        let pulses = !reduceMotion && kind == .tap
        let side = squareSide
        let margin = (Metrics.side - side) / 2
        return FocusSquare()
            .fill(CameraPalette.focusReticle, style: FillStyle(eoFill: true))
            .frame(width: side, height: side)
            .offset(x: margin, y: margin)
            .animation(reduceMotion ? nil : CameraMotion.FocusLock.release, value: lock.isPressing)
            .keyframeAnimator(initialValue: 1.0, trigger: hasSettled) { content, opacity in
                content.opacity(pulses ? opacity : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(Metrics.pulseOpacity, duration: Self.half, startVelocity: 0, endVelocity: 0)
                    CubicKeyframe(1, duration: Self.half, startVelocity: 0, endVelocity: 0)
                    CubicKeyframe(Metrics.pulseOpacity, duration: Self.half, startVelocity: 0, endVelocity: 0)
                    CubicKeyframe(1, duration: Self.half, startVelocity: 0, endVelocity: 0)
                }
            }
            .keyframeAnimator(initialValue: 1.0, repeating: lock.isSettling && !reduceMotion) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(Metrics.pulseOpacity, duration: Self.half, startVelocity: 0, endVelocity: 0)
                    CubicKeyframe(1, duration: Self.half, startVelocity: 0, endVelocity: 0)
                }
            }
            .accessibilityElement()
            .accessibilityIdentifier(CameraIdentifier.focusReticle)
            .accessibilityLabel(CameraControlText(localization).focus)
    }

    private var sunValue: Double {
        ExposureDrag.sunValue(forBias: settings.exposureBias)
    }

    private var sunCenter: CGPoint {
        CGPoint(
            x: Metrics.side / 2 + FocusReticleLayout.sunOffsetFromCenter(on: side),
            y: Metrics.side / 2 - ExposureDrag.sunHeight(forBias: settings.exposureBias)
        )
    }

    private var rail: some View {
        let rail = FocusReticleLayout.Rail(
            sunHeight: ExposureDrag.sunHeight(forBias: settings.exposureBias),
            sun: FocusReticleLayout.Sun(value: sunValue)
        )
        let middle = Metrics.side / 2
        return ZStack(alignment: .topLeading) {
            railPiece(rail.upper, middle: middle)
            railPiece(rail.lower, middle: middle)
        }
        .opacity(isRailVisible ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func railPiece(_ range: ClosedRange<CGFloat>, middle: CGFloat) -> some View {
        Rectangle()
            .fill(CameraPalette.focusReticle)
            .frame(width: Metrics.railWidth, height: range.upperBound - range.lowerBound)
            .offset(x: sunCenter.x - Metrics.railWidth / 2, y: middle + range.lowerBound)
    }

    private var exposureSun: some View {
        FocusSun(value: sunValue)
            .fill(CameraPalette.focusReticle)
            .frame(width: Metrics.sunMaximumExtent * 2, height: Metrics.sunMaximumExtent * 2)
            .offset(x: sunCenter.x - Metrics.sunMaximumExtent, y: sunCenter.y - Metrics.sunMaximumExtent)
            .accessibilityElement()
            .accessibilityIdentifier(CameraIdentifier.focusReticleExposure)
            .accessibilityLabel(CameraSettingSpeech(localization).name(of: .exposure))
            .accessibilityValue(CameraSettingSpeech(localization).value(of: .exposure, in: settings))
            .exposureAdjustableAction(adjustExposure)
            // A bias the app fixed is no control, so accessibility offers none.
            .accessibilityHidden(!settings.isExposureAdjustable)
    }

    /// The rail stays while a finger is down and fades one second after the last change.
    private func fadeRailAfterHold() async {
        guard railFadeRequest > 0, isRailVisible, !isAdjusting else { return }
        do {
            try await Task.sleep(for: CameraMotion.Reticle.railHoldDuration)
            // A cancel that comes after the sleep ended still keeps the rail.
            try Task.checkCancellation()
        } catch {
            return
        }
        withAnimation(reduceMotion ? nil : CameraMotion.Reticle.railFade) {
            isRailVisible = false
        }
    }
}

/// The outline of the focus square with a short tick at the middle of every side.
private struct FocusSquare: Shape {

    func path(in bounds: CGRect) -> Path {
        let metrics = CameraMetrics.FocusReticle.self
        let line = metrics.lineWidth
        let tick = metrics.tickLength
        let tickWidth = metrics.tickWidth
        let half = tickWidth / 2
        var path = Path()
        path.addRect(bounds)
        path.addRect(bounds.insetBy(dx: line, dy: line))
        path.addRect(CGRect(x: bounds.midX - half, y: bounds.minY + line, width: tickWidth, height: tick))
        path.addRect(CGRect(x: bounds.midX - half, y: bounds.maxY - line - tick, width: tickWidth, height: tick))
        path.addRect(CGRect(x: bounds.minX + line, y: bounds.midY - half, width: tick, height: tickWidth))
        path.addRect(CGRect(x: bounds.maxX - line - tick, y: bounds.midY - half, width: tick, height: tickWidth))
        return path
    }
}
#endif
