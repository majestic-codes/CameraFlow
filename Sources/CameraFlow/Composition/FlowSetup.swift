//
//  FlowSetup.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The closures of the flow's events, each nil where it was not given: the ones a `CameraFlowView` was created with,
/// or the ones the SwiftUI modifiers of the flow set around it.
struct FlowCallbacks {
    var onPreferencesChange: ((CameraFlowPreferences) -> Void)?
    var onFinish: (([CameraFlowPhoto]) -> Void)?
    var onCancel: (() -> Void)?

    /// These closures with the ones of `modifiers` over them: a closure a modifier set replaces the one of its event,
    /// so every event has one receiver.
    func overridden(by modifiers: Self) -> Self {
        Self(
            onPreferencesChange: modifiers.onPreferencesChange ?? onPreferencesChange,
            onFinish: modifiers.onFinish ?? onFinish,
            onCancel: modifiers.onCancel ?? onCancel
        )
    }
}

/// The receivers of a flow's events: the closures of the latest `CameraFlowView` of the flow, with the ones of its
/// modifiers over them. The view hands them over at every update, and the flow calls whatever it holds when an
/// event comes, as SwiftUI calls the latest action of a modifier such as `onSubmit`. It belongs to whoever owns the
/// flow, so that a view created again reaches the flow that runs.
final class FlowReceivers {
    private var callbacks = FlowCallbacks()

    /// Whether there is a receiver of the set and of the user's exit.
    var hasRequiredReceivers: Bool {
        callbacks.onFinish != nil && callbacks.onCancel != nil
    }

    /// Takes the closures of the latest view.
    /// - Parameters:
    ///   - callbacks: The closures the view was created with.
    ///   - modifierCallbacks: The closures the modifiers around the view set.
    func update(callbacks: FlowCallbacks, modifierCallbacks: FlowCallbacks) {
        self.callbacks = callbacks.overridden(by: modifierCallbacks)
    }

    func preferencesChanged(_ preferences: CameraFlowPreferences) {
        callbacks.onPreferencesChange?(preferences)
    }

    /// Hands the accepted set to the latest receiver.
    /// - Precondition: the latest view has a receiver of the set.
    func finish(with photos: [CameraFlowPhoto]) {
        guard let onFinish = callbacks.onFinish else {
            preconditionFailure(
                "CameraFlow: the CameraFlowView of a running flow lost its onFinish and onCameraFlowFinish(perform:), "
                    + "and the accepted set has no receiver"
            )
        }
        onFinish(photos)
    }

    /// Tells the latest receiver that the user left without a set.
    /// - Precondition: the latest view has a receiver of the exit.
    func cancel() {
        guard let onCancel = callbacks.onCancel else {
            preconditionFailure(
                "CameraFlow: the CameraFlowView of a running flow lost its onCancel and onCameraFlowCancel(perform:)"
            )
        }
        onCancel()
    }
}

/// What a `CameraFlowView` starts its flow with: the configuration it was created with and the properties the SwiftUI
/// modifiers of the flow set over it, read and checked once, when the flow starts, and the closures that reach the
/// latest receivers of its events.
struct FlowSetup {
    /// The configuration the view was created with, with every property a modifier set replaced.
    let configuration: CameraFlowConfiguration
    let onPreferencesChange: (CameraFlowPreferences) -> Void
    let onFinish: ([CameraFlowPhoto]) -> Void
    let onCancel: () -> Void

    /// Applies the modifiers over the view's own configuration.
    /// - Parameters:
    ///   - configuration: The configuration the view was created with.
    ///   - changes: The properties the modifiers set.
    ///   - receivers: The receivers of the flow's events, which the view updated with its closures.
    ///   - hasLocationProvider: Whether the view was created with a `locationProvider`.
    /// - Precondition: the configuration with the changes applied passes the checks of the configuration, there is
    ///   no location provider while it records no location, and there is a receiver of the set and of the user's exit,
    ///   from the view or from a modifier.
    init(
        configuration: CameraFlowConfiguration,
        changes: FlowConfigurationChanges,
        receivers: FlowReceivers,
        hasLocationProvider: Bool
    ) {
        let changed = changes.applied(to: configuration)
        changed.validate(hasLocationProvider: hasLocationProvider)
        precondition(
            receivers.hasRequiredReceivers,
            "CameraFlow: a CameraFlowView created without onFinish and onCancel needs onCameraFlowFinish(perform:) and "
                + "onCameraFlowCancel(perform:) on it or on a view around it"
        )
        self.configuration = changed
        onPreferencesChange = { receivers.preferencesChanged($0) }
        onFinish = { receivers.finish(with: $0) }
        onCancel = { receivers.cancel() }
    }
}
