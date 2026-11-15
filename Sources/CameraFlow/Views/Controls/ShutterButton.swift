//
//  ShutterButton.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The shutter: a white disc inside a lit glass ring. The disc shrinks while pressed.
///
/// A tap while the self-timer runs cancels it instead, and the label says so. The shutter is dimmed and inert
/// while the set takes no more photos. It is inert as well while the camera is busy with the photos before, as the
/// stock camera's shutter is: its disc dims while the camera takes a photo that lasts, such as one with the flash, and
/// a spinner turns around the disc while the camera processes the photos it took.
struct ShutterButton: View {
    @Environment(\.flowLocalization) private var localization
    let shutter: ShutterModel
    let panel: ControlPanelModel
    let layout: CameraScreenLayout
    let isEnabled: Bool
    /// Takes a photo, or cancels the self-timer while it runs.
    let capture: () async -> Void

    /// The tile grid of the control panel lies over the shutter, and its glass would let the white disc glow
    /// through, which the stock panel does not show.
    private var isCovered: Bool {
        panel.presentation == .tiles
    }

    var body: some View {
        Button {
            Task {
                await capture()
            }
        } label: {
            Color.clear
        }
        .buttonStyle(ShutterButtonStyle(busyIndication: shutter.busyIndication))
        .accessibilityIdentifier(CameraIdentifier.shutter)
        .accessibilityLabel(CameraControlText(localization).shutter(isCountingDown: shutter.countdownSeconds != nil))
        .disabled(!isEnabled || !shutter.takesTap)
        .opacity(isEnabled ? 1 : CameraPalette.unavailableOpacity)
        .animation(FlowMotion.availability, value: isEnabled)
        .opacity(isCovered ? 0 : 1)
        .allowsHitTesting(!isCovered)
        .accessibilityHidden(isCovered)
        .placed(in: layout.shutter)
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    /// How the shutter shows that the camera is busy.
    let busyIndication: ShutterBusyIndication

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            ShutterRing()
            Circle()
                .fill(CameraPalette.shutterDisc)
                .frame(width: CameraMetrics.Shutter.discDiameter, height: CameraMetrics.Shutter.discDiameter)
                .opacity(busyIndication == .unchanged ? 1 : CameraPalette.unavailableOpacity)
                .scaleEffect(configuration.isPressed ? CameraMotion.Shutter.pressedScale : 1)
                .animation(CameraMotion.Shutter.press, value: configuration.isPressed)
            if busyIndication == .spinning {
                ShutterSpinner()
                    .transition(.opacity)
            }
        }
        .animation(FlowMotion.availability, value: busyIndication)
        .frame(width: CameraMetrics.Shutter.ringDiameter, height: CameraMetrics.Shutter.ringDiameter)
        .contentShape(Circle())
    }
}

/// The ring around the shutter disc: a dark glass band with a rim that catches light at the top and the bottom.
private struct ShutterRing: View {
    var body: some View {
        let metrics = CameraMetrics.Shutter.self
        let outerRadius = metrics.ringDiameter / 2
        let innerRadius = metrics.discDiameter / 2
        let innerRim = Self.angular(CameraPalette.shutterRim, share: metrics.innerRimShare)
        ZStack {
            Circle()
                .fill(CameraPalette.glassFill)
            Circle()
                .fill(Self.glow(from: innerRadius, to: outerRadius))
                .mask(Circle().fill(Self.angular(CameraPalette.shutterGlow, share: 1)))
            Circle()
                .strokeBorder(Self.angular(CameraPalette.shutterRim, share: 1), lineWidth: metrics.rimWidth)
            Circle()
                .inset(by: metrics.rimWidth)
                .strokeBorder(innerRim, lineWidth: metrics.rimWidth)
        }
    }

    private static func glow(from innerRadius: CGFloat, to outerRadius: CGFloat) -> RadialGradient {
        let stops = CameraPalette.shutterGlowStops
        return RadialGradient(stops: stops, center: .center, startRadius: innerRadius, endRadius: outerRadius)
    }

    private static func angular(_ opacities: [Double], share: Double) -> AngularGradient {
        let lastIndex = Double(opacities.count - 1)
        let stops = opacities.enumerated().map { index, opacity in
            Gradient.Stop(color: .white.opacity(opacity * share), location: Double(index) / lastIndex)
        }
        return AngularGradient(gradient: Gradient(stops: stops), center: .center, angle: .degrees(-90))
    }
}

/// The spinner of a busy shutter, centred in the band between the disc and the rim: a white head that turns
/// clockwise and a tail behind it that fades out over a full turn.
private struct ShutterSpinner: View {
    var body: some View {
        let metrics = CameraMetrics.Shutter.self
        let diameter = (metrics.ringDiameter + metrics.discDiameter) / 2
        let turn = CameraMotion.Shutter.spinnerTurn
        TimelineView(.animation) { context in
            let progress = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: turn) / turn
            ZStack {
                Circle()
                    .stroke(Self.tail, lineWidth: metrics.spinnerWidth)
                Circle()
                    .fill(CameraPalette.shutterDisc)
                    .frame(width: metrics.spinnerWidth, height: metrics.spinnerWidth)
                    .offset(x: diameter / 2)
            }
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(progress * 360))
        }
    }

    /// The tail, clear right after the head at the trailing edge and white as it comes round to the head again.
    private static let tail = AngularGradient(
        colors: [CameraPalette.shutterDisc.opacity(0), CameraPalette.shutterDisc],
        center: .center,
        startAngle: .zero,
        endAngle: .degrees(360)
    )
}
#endif
