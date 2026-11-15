//
//  CameraCaptureButtons.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVKit
import SwiftUI
import UIKit

/// The hardware capture buttons, the Camera Control and the volume buttons: a full press takes a photo through
/// `capture`, on release as the stock camera does. Off while the flow takes no photo from them, which gives the
/// buttons back to the system. Nothing is added before iOS 17.2.
struct CameraCaptureButtons: ViewModifier {
    let isEnabled: Bool
    let capture: () async -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onCameraCaptureEvent(isEnabled: isEnabled) { event in
                handle(event.phase)
            }
        } else if #available(iOS 17.2, *) {
            content.background {
                CaptureEventInteractionView(isEnabled: isEnabled) { phase in
                    handle(phase)
                }
            }
        } else {
            content
        }
    }

    @available(iOS 17.2, *)
    private func handle(_ phase: AVCaptureEventPhase) {
        guard phase == .ended else { return }
        Task {
            await capture()
        }
    }
}

/// Hides a control while the Camera Control's overlay is fullscreen, from accessibility too.
struct CaptureOverlayHiding: ViewModifier {
    let captureControls: CaptureControlsModel
    let panel: ControlPanelModel

    func body(content: Content) -> some View {
        let isHidden = captureControls.hidesControls
        content
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
            .animation(CameraMotion.Panel.animation(to: panel.presentation), value: isHidden)
    }
}

/// `AVCaptureEventInteraction` on a view of its own, for iOS 17.2 to 17.x where SwiftUI has no modifier for it.
@available(iOS 17.2, *)
private struct CaptureEventInteractionView: UIViewRepresentable {
    let isEnabled: Bool
    let onPhase: (AVCaptureEventPhase) -> Void

    final class Coordinator {
        var onPhase: (AVCaptureEventPhase) -> Void

        init(onPhase: @escaping (AVCaptureEventPhase) -> Void) {
            self.onPhase = onPhase
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhase: onPhase)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let coordinator = context.coordinator
        let interaction = AVCaptureEventInteraction { event in
            coordinator.onPhase(event.phase)
        }
        interaction.isEnabled = isEnabled
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onPhase = onPhase
        for case let interaction as AVCaptureEventInteraction in view.interactions {
            interaction.isEnabled = isEnabled
        }
    }
}
#endif
