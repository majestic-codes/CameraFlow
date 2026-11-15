//
//  CameraFlowViewController.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreLocation
import SwiftUI
import UIKit

/// Receives what the flow of a ``CameraFlowViewController`` tells its app, on the main actor: the closures of the
/// controller hear the same, so an app listens through one of the two.
@MainActor
public protocol CameraFlowViewControllerDelegate: AnyObject {

    /// The user accepted the set: the photos in their order, once. The receiver owns their files.
    func cameraFlowViewController(_ controller: CameraFlowViewController, didFinishWith photos: [CameraFlowPhoto])
    /// The user left the flow without a set.
    func cameraFlowViewControllerDidCancel(_ controller: CameraFlowViewController)
    /// The user changed an adjustable setting: the choices to store.
    func cameraFlowViewController(_ controller: CameraFlowViewController, didChange preferences: CameraFlowPreferences)
}

extension CameraFlowViewControllerDelegate {

    /// Ignored unless the delegate stores preferences.
    public func cameraFlowViewController(
        _ controller: CameraFlowViewController,
        didChange preferences: CameraFlowPreferences
    ) {}
}

/// The whole "Add photo" flow as a view controller, for an app built on UIKit.
///
/// Present it and it does the rest: it covers the whole screen (`modalPresentationStyle` is `.fullScreen`, so the
/// presenter gets its usual appearance calls), keeps its interface portrait on iPhone while it is on screen in an app
/// that rotates (iPad turns it with the device), hides the status bar and the home indicator, makes the system alerts
/// and sheets of the flow dark, and dismisses itself once the flow finished or was cancelled
/// (``dismissesAutomatically``). It cannot be swiped away: the cross is the user's way out, and it asks before it
/// leaves photos behind, the photos of the set and the ones the camera is still taking or processing.
///
/// ```swift
/// let controller = CameraFlowViewController(
///     configuration: configuration,
///     onFinish: { photos in keep(photos) },
///     onCancel: {}
/// )
/// present(controller, animated: true)
/// ```
///
/// An app that listens through the ``delegate`` passes no closures:
///
/// ```swift
/// let controller = CameraFlowViewController(configuration: configuration)
/// controller.delegate = self
/// present(controller, animated: true)
/// ```
///
/// Every presentation runs a new flow with an empty set and reports it once, so one controller may be presented again,
/// and it then shows its new flow until that flow ends, also when the flow before ended while the controller was
/// leaving the screen. A screen the app presents over the controller keeps the set, and the camera comes back when it
/// leaves. The flow ends when the controller is dismissed: a set nobody accepted is deleted then.
///
/// Every result reaches both the closures and the ``delegate``, on the main actor, before the controller dismisses
/// itself, so an app listens through one of the two: through both, it would take each set twice. The hand-over of
/// an accepted set outlives the screen, and the controller stays until a hand-over that began on it has ended: its
/// delegate hears the set even when the app dismissed and released the controller meanwhile. A delegate that no
/// longer exists hears nothing, and a set that reaches neither `onFinish` nor a delegate is deleted, as with a
/// closure that captured its owner weakly: an app whose sets must arrive whatever becomes of its delegate passes
/// `onFinish`. An app that shows another screen after the flow dismisses the controller first and presents that
/// screen from the completion of the dismissal: set ``dismissesAutomatically`` to false and call
/// `dismiss(animated:completion:)` in `onFinish`. A sheet presented over the flow shares its dark window. The flow is
/// the one ``CameraFlowView`` runs: see it for the configuration, the files, the location and the preferences.
///
/// The controller takes its configuration and its closures from its initializer only, and its results reach the
/// closures and the ``delegate``. The SwiftUI modifiers of the flow (<doc:SwiftUIModifiers>) are for
/// ``CameraFlowView``: the controller hosts its flow in a hierarchy of its own, which no modifier of the app reaches.
public final class CameraFlowViewController: UIViewController {
    /// Receives the results besides the closures. Weak, as a delegate is.
    public weak var delegate: (any CameraFlowViewControllerDelegate)?
    /// Whether the controller dismisses itself once the flow finished or was cancelled, after the results were
    /// delivered. Default true. It waits for a sheet or an alert of the flow that is still leaving, and takes the
    /// ones that stay with it.
    public var dismissesAutomatically = true

    private let relay: FlowOutcomeRelay
    private let host: PortraitHostingController<CameraFlowView>
    /// The dismissal the controller asks of itself once its flow has ended, which waits for a presentation or a
    /// transition that runs and ends once the controller leaves.
    private var selfDismissal = FlowSelfDismissal()

    /// Creates the controller over a flow. The closures are optional for an app that listens through the delegate,
    /// but a controller on screen needs a receiver for the sets the user accepts: `onFinish` or the delegate. Every
    /// closure is called on the main actor, where the controller is created: see ``CameraFlowView``.
    /// - Parameters:
    ///   - configuration: What the flow offers and how its camera opens.
    ///   - locationProvider: The app's own location for the photos, called at every shutter release, in place of the
    ///     flow's. A location it returns counts as the flow's own does, while it is valid and at most 60 seconds old,
    ///     or 20 minutes for an approximate one. Nil for the flow's own (``CameraFlowConfiguration/photoLocation``).
    ///   - onPreferencesChange: Receives the user's choices (``CameraFlowPreferences``) after every change the user
    ///     makes to an adjustable setting.
    ///   - onFinish: Receives the photos of the set in their order, once, when the user accepts the set.
    ///   - onCancel: Called when the user leaves the flow without a set.
    /// - Precondition: the preconditions of ``CameraFlowView/init(configuration:locationProvider:)`` over the
    ///   configuration and the location provider. Once the controller is on screen there is `onFinish` or a
    ///   ``delegate``: without either the photos of an accepted set would be lost.
    public init(
        configuration: CameraFlowConfiguration = CameraFlowConfiguration(),
        locationProvider: (() -> CLLocation?)? = nil,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil,
        onFinish: (([CameraFlowPhoto]) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        let relay = FlowOutcomeRelay(onPreferencesChange: onPreferencesChange, onFinish: onFinish, onCancel: onCancel)
        self.relay = relay
        let flow = CameraFlowView(
            configuration: configuration,
            locationProvider: locationProvider,
            onPreferencesChange: { relay.preferencesChanged($0) },
            onFinish: { relay.finish(with: $0) },
            onCancel: { relay.cancel() }
        )
        host = PortraitHostingController(content: flow, handOverObserver: relay)
        super.init(nibName: nil, bundle: nil)
        relay.receiver = self
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    @available(*, unavailable, message: "CameraFlowViewController is created in code")
    public required init?(coder: NSCoder) {
        nil
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        precondition(
            relay.deliversSets,
            "CameraFlowViewController needs onFinish or a delegate: the photos of an accepted set would be lost"
        )
        continuePendingDismissal()
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        host.flowOrientations.mask
    }

    override public var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        host.flowOrientations.preferredOrientation
    }

    override public var shouldAutorotate: Bool {
        host.flowOrientations.quarters.count > 1
    }

    override public var childForStatusBarHidden: UIViewController? {
        host
    }

    override public var childForStatusBarStyle: UIViewController? {
        host
    }

    override public var childForHomeIndicatorAutoHidden: UIViewController? {
        host
    }

    // MARK: - Dismissal

    /// Dismisses the controller once the flow on screen has ended, through its presenter, so the sheets and the
    /// alerts the flow shows go with it. A set handed over late, after a new presentation began, leaves the new flow
    /// on screen.
    private func dismissIfAutomatic() {
        guard dismissesAutomatically, host.hasFlowEnded else { return }
        follow(selfDismissal.request(phase: presentationPhase, covering: covering))
    }

    /// Lets a dismissal that waits go on, once the controller has appeared or a transition has ended.
    private func continuePendingDismissal() {
        follow(selfDismissal.proceed(phase: presentationPhase, covering: covering))
    }

    private func follow(_ step: FlowPresentationStep) {
        switch step {
        case .dismiss:
            presentingViewController?.dismiss(animated: true)
        case .retryAfterTransition:
            retryDismissalAfterTransition()
        case .stay, .present, .updateContent, .retryNextTurn:
            break
        }
    }

    private var presentationPhase: FlowPresentationPhase {
        if presentingViewController == nil {
            return .absent
        }
        if isBeingPresented {
            return .appearing
        }
        return isBeingDismissed ? .leaving : .shown
    }

    /// The controllers from this one to the one presented on top of it.
    private var presentationStack: [UIViewController] {
        Array(sequence(first: self as UIViewController, next: \.presentedViewController))
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

    private func retryDismissalAfterTransition() {
        guard let coordinator = presentationStack.lazy.compactMap(\.transitionCoordinator).first else {
            Task { [weak self] in
                self?.continuePendingDismissal()
            }
            return
        }
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.continuePendingDismissal()
        }
    }
}

extension CameraFlowViewController: FlowOutcomeReceiver {
    var hasDelegate: Bool {
        delegate != nil
    }

    func flowFinished(with photos: [CameraFlowPhoto]) {
        delegate?.cameraFlowViewController(self, didFinishWith: photos)
        dismissIfAutomatic()
    }

    func flowFinishedWithoutReceiver() {
        dismissIfAutomatic()
    }

    func flowCancelled() {
        delegate?.cameraFlowViewControllerDidCancel(self)
        dismissIfAutomatic()
    }

    func preferencesChanged(_ preferences: CameraFlowPreferences) {
        delegate?.cameraFlowViewController(self, didChange: preferences)
    }
}
#endif
