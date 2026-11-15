//
//  CameraFlowUIKitPresenter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os
import CameraFlow
import SwiftUI
import UIKit

extension View {

    /// Presents the camera flow of the example the way a UIKit app opens it once the binding turns true: a
    /// `CameraFlowViewController` presented from the controller that shows this view, so in this view's window, with
    /// no SwiftUI cover around it. The binding turns false once the flow is on screen, and the controller dismisses
    /// itself when the flow ends.
    func exampleCameraFlowController(
        isRequested: Binding<Bool>,
        options: CameraFlowLaunchOptions,
        onFinish: @escaping (CameraFlowOutcomeLog.Outcome) -> Void
    ) -> some View {
        background(
            CameraFlowUIKitPresenter(isRequested: isRequested, options: options, onFinish: onFinish)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

/// Bridges the request of the stand to a controller in its hierarchy, which presents the flow as a UIKit app does.
private struct CameraFlowUIKitPresenter: UIViewControllerRepresentable {
    private static let logger = Logger(subsystem: "CameraFlowExample", category: "CameraFlowUIKit")

    @Binding var isRequested: Bool
    let options: CameraFlowLaunchOptions
    let onFinish: (CameraFlowOutcomeLog.Outcome) -> Void

    func makeUIViewController(context: Context) -> CameraFlowPresentingController {
        CameraFlowPresentingController()
    }

    func updateUIViewController(_ controller: CameraFlowPresentingController, context: Context) {
        let request = $isRequested
        if isRequested {
            controller.requestedFlow = { makeFlow() }
        } else {
            controller.requestedFlow = nil
        }
        controller.onPresented = {
            request.wrappedValue = false
        }
        controller.presentRequestedFlow()
    }

    /// The flow as a UIKit app creates it, with the example's configuration and its own way of keeping the photos.
    private func makeFlow() -> CameraFlowViewController {
        CameraFlowViewController(
            configuration: CameraFlowPreferencesStore.configuration(for: options),
            onPreferencesChange: CameraFlowPreferencesStore.store,
            onFinish: { photos in
                Self.logger.notice("camera flow (UIKit) finished with \(photos.count) photos")
                onFinish(CameraFlowOutcomeLog.keep(photos))
            },
            onCancel: {
                Self.logger.notice("camera flow (UIKit) cancelled")
            }
        )
    }
}

/// An empty controller in the stand's hierarchy. It presents the flow asked for once it is in a window and nothing is
/// presented over it, as a UIKit app presents from the controller that owns the button.
private final class CameraFlowPresentingController: UIViewController {
    /// Creates the flow asked for, nil while none is.
    var requestedFlow: (() -> CameraFlowViewController)?
    /// Called once the flow asked for is on screen.
    var onPresented: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentRequestedFlow()
    }

    func presentRequestedFlow() {
        guard let requestedFlow, viewIfLoaded?.window != nil, presentedViewController == nil else { return }
        present(requestedFlow(), animated: true) { [weak self] in
            self?.requestedFlow = nil
            self?.onPresented?()
        }
    }
}
