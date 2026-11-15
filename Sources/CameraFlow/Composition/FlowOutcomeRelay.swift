//
//  FlowOutcomeRelay.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The controller that presents the flows a relay reports, while it exists: its delegate and its dismissal.
@MainActor
protocol FlowOutcomeReceiver: AnyObject {
    /// Whether the receiver has a delegate that hears an accepted set.
    var hasDelegate: Bool { get }
    func flowFinished(with photos: [CameraFlowPhoto])
    /// The user accepted a set that reached nobody, so it was deleted: the flow ended without a set.
    func flowFinishedWithoutReceiver()
    func flowCancelled()
    func preferencesChanged(_ preferences: CameraFlowPreferences)
}

/// Carries what the flows of `CameraFlowViewController` report to its app. The app's closures hear every report,
/// also of a set accepted before the controller went away, since the hand-over outlives the screen. The controller,
/// whose delegate callbacks take the controller, hears them while it exists, and the relay keeps it for as long as a
/// hand-over that began on it runs: a controller the app released meanwhile still tells its delegate. A set that
/// reaches neither `onFinish` nor a delegate is deleted by its set, which asks the relay first. The flow's view is made
/// before the controller is, so the view holds the relay and the relay holds the controller weakly between
/// hand-overs.
@MainActor
final class FlowOutcomeRelay {
    weak var receiver: (any FlowOutcomeReceiver)?
    private let onPreferencesChange: ((CameraFlowPreferences) -> Void)?
    private let onFinish: (([CameraFlowPhoto]) -> Void)?
    private let onCancel: (() -> Void)?
    /// Keeps the receiver while hand-overs that began on it run, nil while none does.
    private var receiverOfHandOvers: (any FlowOutcomeReceiver)?
    /// How many hand-overs run now: a controller presented again may hand over a new set while an older one runs.
    private var handOverCount = 0

    init(
        onPreferencesChange: ((CameraFlowPreferences) -> Void)?,
        onFinish: (([CameraFlowPhoto]) -> Void)?,
        onCancel: (() -> Void)?
    ) {
        self.onPreferencesChange = onPreferencesChange
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    /// Whether an accepted set reaches anyone: the app's `onFinish`, or the delegate of a receiver that exists.
    var deliversSets: Bool {
        onFinish != nil || receiver?.hasDelegate == true
    }

    /// An accepted set, which only its receiver may delete.
    func finish(with photos: [CameraFlowPhoto]) {
        onFinish?(photos)
        receiver?.flowFinished(with: photos)
    }

    func cancel() {
        onCancel?()
        receiver?.flowCancelled()
    }

    func preferencesChanged(_ preferences: CameraFlowPreferences) {
        onPreferencesChange?(preferences)
        receiver?.preferencesChanged(preferences)
    }
}

extension FlowOutcomeRelay: PhotoSetHandOverObserver {

    func handOverBegan() {
        handOverCount += 1
        receiverOfHandOvers = receiver
    }

    var receivesSets: Bool {
        deliversSets
    }

    func setDeleted() {
        receiver?.flowFinishedWithoutReceiver()
    }

    func handOverEnded() {
        handOverCount -= 1
        if handOverCount == 0 {
            receiverOfHandOvers = nil
        }
    }
}
