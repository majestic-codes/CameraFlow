//
//  CameraFlowCover.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import os
import SwiftUI
import UIKit

extension View {

    /// Presents the camera flow full screen in a controller of its own, so its interface stays portrait on iPhone while
    /// the rest of the app may rotate. On iPad the interface turns with the device. The window is dark while the flow
    /// covers it, which makes the system alerts of the flow dark, and has its own style again as the flow leaves.
    ///
    /// Works like `fullScreenCover(isPresented:onDismiss:content:)`: setting the binding to false dismisses the
    /// content, together with any sheet or alert the flow shows, and the binding becomes false however the content
    /// is dismissed. A change that comes while a presentation or a dismissal runs, or while another sheet is
    /// leaving, waits for it to end. A sheet that stays on screen gets the flow over it.
    ///
    /// The flow lives as long as the cover: a screen the app presents over it keeps its set, and the camera comes
    /// back when that screen leaves. The content is hosted by its own controller, so it does not inherit this view's
    /// environment, with one exception: the SwiftUI modifiers of the flow, such as
    /// ``SwiftUICore/View/cameraFlowPhotoLimit(_:)`` and ``SwiftUICore/View/onCameraFlowFinish(perform:)``, reach the
    /// flow from this view and the views around it, as the environment reaches the content of `fullScreenCover`. A
    /// modifier inside `content` wins over one outside. Pass anything else the content needs explicitly. See
    /// <doc:SwiftUIModifiers>.
    /// - Parameters:
    ///   - isPresented: Whether the flow is presented.
    ///   - onDismiss: Called after the flow has been dismissed.
    ///   - content: The flow, a ``CameraFlowView``.
    public func cameraFlowCover<FlowContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> FlowContent
    ) -> some View {
        background(
            CameraFlowCoverPresenter(isPresented: isPresented, onDismiss: onDismiss, content: content)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

/// Bridges the binding to a controller in the hierarchy that presents and dismisses the cover.
private struct CameraFlowCoverPresenter<FlowContent: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let content: () -> FlowContent

    func makeUIViewController(context: Context) -> CameraFlowCoverAnchor<FlowContent> {
        CameraFlowCoverAnchor()
    }

    func updateUIViewController(_ anchor: CameraFlowCoverAnchor<FlowContent>, context: Context) {
        let binding = $isPresented
        anchor.isPresented = isPresented
        anchor.content = content
        anchor.inheritedModifiers = context.environment.flowModifierEnvironment
        anchor.onDismissedByContent = {
            binding.wrappedValue = false
        }
        anchor.onDismissed = onDismiss
        anchor.synchronize()
    }

    static func dismantleUIViewController(_ anchor: CameraFlowCoverAnchor<FlowContent>, coordinator: ()) {
        anchor.isPresented = false
        anchor.synchronize()
    }
}

/// An empty controller that presents the cover once it can and keeps it in step with the binding, the way
/// `FlowPresentationPlan` says: a step the system would refuse now waits for the presentation or the dismissal that
/// runs, or for the next turn, and is tried again. A wait holds the controller, so that a cover asked to leave as
/// SwiftUI takes the controller away still leaves.
final class CameraFlowCoverAnchor<FlowContent: View>: UIViewController {
    var isPresented = false
    var content: (() -> FlowContent)?
    /// The modifiers of the flow around the presenting view, which the cover carries into the flow.
    var inheritedModifiers = FlowModifierEnvironment()
    /// Called when the cover went away without `isPresented` turning false, so the binding has to follow.
    var onDismissedByContent: (() -> Void)?
    var onDismissed: (() -> Void)?
    private var cover: PortraitHostingController<FlowContent>?
    private var phase = FlowPresentationPhase.absent
    /// Whether the request waited a turn already for a controller presented in its way.
    private var hasWaitedNextTurn = false
    /// Whether a retry is scheduled, so that another one does not stack on it.
    private var isRetryScheduled = false

    private static var logger: Logger {
        Logger.camera("CameraFlowCover")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        synchronize()
    }

    /// Presents, updates or dismisses the cover to match `isPresented`.
    func synchronize() {
        if !isPresented {
            hasWaitedNextTurn = false
        }
        let plan = FlowPresentationPlan(
            isRequested: isPresented,
            canPresent: content != nil && viewIfLoaded?.window != nil,
            phase: phase,
            covering: covering,
            hasWaitedNextTurn: hasWaitedNextTurn
        )
        switch plan.step {
        case .stay:
            break
        case let .present(overPresentedController):
            presentCover(overPresentedController: overPresentedController)
        case .updateContent:
            if let cover, let content {
                cover.show(content(), inheritedModifiers: inheritedModifiers)
            }
        case .dismiss:
            dismissCover()
        case .retryAfterTransition:
            retryAfterTransition()
        case .retryNextTurn:
            retryNextTurn()
        }
    }

    /// The controllers from the one the plan looks over to the one presented on top: the cover while it is there,
    /// and this controller, which reports what its ancestors present, while it is not.
    private var presentationStack: [UIViewController] {
        let base: UIViewController = cover ?? self
        return Array(sequence(first: base, next: \.presentedViewController))
    }

    private var covering: CoveringControllers {
        let stack = presentationStack
        let isMoving = stack.contains { controller in
            controller.transitionCoordinator != nil || controller.isBeingPresented || controller.isBeingDismissed
        }
        if isMoving {
            return .moving
        }
        return stack.count > 1 ? .settled : .clear
    }

    /// The controller presented on top of this one's ancestors, this controller itself when they present none.
    private var topmostPresented: UIViewController {
        var controller: UIViewController = self
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }

    private func presentCover(overPresentedController: Bool) {
        guard let content else { return }
        let presenter: UIViewController = overPresentedController ? topmostPresented : self
        let presented = PortraitHostingController(content: content(), inheritedModifiers: inheritedModifiers)
        // The presenter's views stay in the window under the cover: SwiftUI stops updating a hierarchy that is in
        // no window, and this controller is part of it, so it would never learn that the binding turned false.
        presented.modalPresentationStyle = .overFullScreen
        presented.modalPresentationCapturesStatusBarAppearance = true
        presented.onDismissed = { [weak self, weak presented] in
            guard let self, let presented, cover === presented else { return }
            coverDismissed()
        }
        cover = presented
        phase = .appearing
        hasWaitedNextTurn = false
        presenter.present(presented, animated: true) { [self, weak presented] in
            guard let presented, cover === presented, phase == .appearing else { return }
            phase = .shown
            synchronize()
        }
        guard presented.presentingViewController == nil else { return }
        Self.logger.error("The system refused to present the camera flow, and the binding turns false")
        cover = nil
        phase = .absent
        isPresented = false
        // The binding changes on the next turn: this may run while SwiftUI updates the view that owns it.
        Task { [self] in
            onDismissedByContent?()
        }
    }

    /// Dismisses the cover through the controller that presented it, which takes down the sheets and the alerts the
    /// flow shows over it as well.
    private func dismissCover() {
        guard let cover, let presenter = cover.presentingViewController else {
            cover = nil
            phase = .absent
            return
        }
        phase = .leaving
        presenter.dismiss(animated: true)
    }

    private func coverDismissed() {
        let wasAsked = phase == .leaving
        cover = nil
        phase = .absent
        if !wasAsked {
            isPresented = false
            onDismissedByContent?()
        }
        onDismissed?()
        synchronize()
    }

    private func retryAfterTransition() {
        guard !isRetryScheduled else { return }
        guard let coordinator = presentationStack.lazy.compactMap(\.transitionCoordinator).first else {
            retryNextTurn()
            return
        }
        isRetryScheduled = true
        coordinator.animate(alongsideTransition: nil) { [self] _ in
            isRetryScheduled = false
            synchronize()
        }
    }

    private func retryNextTurn() {
        guard !isRetryScheduled else { return }
        isRetryScheduled = true
        Task { [self] in
            isRetryScheduled = false
            hasWaitedNextTurn = true
            synchronize()
        }
    }
}
#endif
