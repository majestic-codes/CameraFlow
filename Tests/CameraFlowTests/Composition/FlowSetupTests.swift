//
//  FlowSetupTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite(
    "What a view starts its flow with, the SwiftUI modifiers over its own values",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct FlowSetupTests {
    /// The closures that were called, by the name of their owner and their event.
    @MainActor
    private final class CalledClosures {
        var names: [String] = []

        func callbacks(of owner: String) -> FlowCallbacks {
            FlowCallbacks(
                onPreferencesChange: { _ in self.names.append("\(owner) preferences") },
                onFinish: { _ in self.names.append("\(owner) finish") },
                onCancel: { self.names.append("\(owner) cancel") }
            )
        }
    }

    /// The setup of a view created with `callbacks` under the modifiers' `changes` and `modifierCallbacks`, whose
    /// update hands the closures to `receivers` first, as `CameraFlowView` does.
    private func setup(
        configuration: CameraFlowConfiguration = CameraFlowConfiguration(),
        changes: FlowConfigurationChanges = FlowConfigurationChanges(),
        callbacks: FlowCallbacks,
        modifierCallbacks: FlowCallbacks = FlowCallbacks(),
        receivers: FlowReceivers = FlowReceivers(),
        hasLocationProvider: Bool = false
    ) -> FlowSetup {
        receivers.update(callbacks: callbacks, modifierCallbacks: modifierCallbacks)
        return FlowSetup(
            configuration: configuration,
            changes: changes,
            receivers: receivers,
            hasLocationProvider: hasLocationProvider
        )
    }

    /// Calls every closure of the setup once, the preferences first, as a flow could.
    private func callEveryClosure(of setup: FlowSetup) {
        setup.onPreferencesChange(CameraFlowPreferences())
        setup.onFinish([])
        setup.onCancel()
    }

    @Test("Without modifiers the flow starts with the view's own configuration and closures")
    func withoutModifiers() {
        let called = CalledClosures()
        var configuration = CameraFlowConfiguration()
        configuration.photoLimit = .maximum(4)
        let started = setup(configuration: configuration, callbacks: called.callbacks(of: "view"))
        #expect(started.configuration == configuration)
        callEveryClosure(of: started)
        #expect(called.names == ["view preferences", "view finish", "view cancel"])
    }

    @Test("The properties the modifiers set replace the configuration's")
    func changedConfiguration() {
        let called = CalledClosures()
        var changes = FlowConfigurationChanges()
        changes.append(.photoLimit(.single))
        changes.append(.libraryPicker(isEnabled: false))
        var configuration = CameraFlowConfiguration()
        configuration.photoLimit = .maximum(4)
        configuration.onboarding = .off
        let started = setup(configuration: configuration, changes: changes, callbacks: called.callbacks(of: "view"))
        #expect(started.configuration == changes.applied(to: configuration))
        #expect(started.configuration.photoLimit == .single)
        #expect(started.configuration.isLibraryPickerEnabled == false)
        #expect(started.configuration.onboarding == .off)
    }

    @Test("A closure a modifier sets replaces the view's own of that event, and the others stay the view's")
    func modifierClosureWins() {
        let called = CalledClosures()
        var modifierCallbacks = FlowCallbacks()
        modifierCallbacks.onFinish = called.callbacks(of: "modifier").onFinish
        let started = setup(callbacks: called.callbacks(of: "view"), modifierCallbacks: modifierCallbacks)
        callEveryClosure(of: started)
        #expect(called.names == ["view preferences", "modifier finish", "view cancel"])
    }

    @Test("A view created without closures takes every one from the modifiers")
    func closuresFromModifiers() {
        let called = CalledClosures()
        let started = setup(callbacks: FlowCallbacks(), modifierCallbacks: called.callbacks(of: "modifier"))
        callEveryClosure(of: started)
        #expect(called.names == ["modifier preferences", "modifier finish", "modifier cancel"])
    }

    @Test("A flow needs no receiver of the preferences")
    func noPreferencesReceiver() {
        let called = CalledClosures()
        var modifierCallbacks = called.callbacks(of: "modifier")
        modifierCallbacks.onPreferencesChange = nil
        let started = setup(callbacks: FlowCallbacks(), modifierCallbacks: modifierCallbacks)
        callEveryClosure(of: started)
        #expect(called.names == ["modifier finish", "modifier cancel"])
    }

    @Test("The flow calls the closures of the latest update of the view, not the ones it started with")
    func latestClosures() {
        let called = CalledClosures()
        let receivers = FlowReceivers()
        let started = setup(callbacks: called.callbacks(of: "first"), receivers: receivers)
        receivers.update(callbacks: FlowCallbacks(), modifierCallbacks: called.callbacks(of: "second"))
        callEveryClosure(of: started)
        var latest = called.callbacks(of: "third")
        latest.onPreferencesChange = nil
        receivers.update(callbacks: latest, modifierCallbacks: FlowCallbacks())
        callEveryClosure(of: started)
        #expect(
            called.names == ["second preferences", "second finish", "second cancel", "third finish", "third cancel"]
        )
    }

    @Test("A location a modifier sets that records one takes the location provider the view was created with")
    func locationWithProvider() {
        let called = CalledClosures()
        var changes = FlowConfigurationChanges()
        changes.append(.photoLocation(.appRequestsAccess))
        let started = setup(changes: changes, callbacks: called.callbacks(of: "view"), hasLocationProvider: true)
        #expect(started.configuration.photoLocation == .appRequestsAccess)
    }

    @Test("A modifier output that keeps the files as they are takes a RAW format the app fixed")
    func rawWithKeptOutput() {
        let called = CalledClosures()
        var configuration = CameraFlowConfiguration()
        configuration.camera.photoFormat = .fixed(.raw)
        var changes = FlowConfigurationChanges()
        changes.append(.output(CameraFlowOutput()))
        let started = setup(configuration: configuration, changes: changes, callbacks: called.callbacks(of: "view"))
        #expect(started.configuration.camera.photoFormat == .fixed(.raw))
    }

    @Test("A flow that ran once keeps what it started with when its view comes back under other modifiers")
    func readOnce() async throws {
        let lifetime = FlowPresentationLifetime<FakeMarkupCanvas>()
        let madeFlows = MadeFlows()
        let firstView = appear(in: lifetime, limit: .maximum(2), making: madeFlows)
        await settle { lifetime.screen != nil }
        firstView.cancel()
        await firstView.value

        let secondView = appear(in: lifetime, limit: .maximum(5), making: madeFlows)
        await settle { lifetime.screen?.flow.camera.session.capabilities != nil }
        let flow = try #require(lifetime.screen?.flow)
        #expect(madeFlows.flows.count == 1)
        #expect(flow.photoSet.limit == .maximum(2))
        secondView.cancel()
        await secondView.value
        lifetime.end()
    }

    /// The flows a presentation made, in their order.
    @MainActor
    private final class MadeFlows {
        let harness = FlowHarness()
        var flows: [TestFlowModel] = []
    }

    /// Runs the presentation as `CameraFlowView` does, with a photo limit of the modifiers as the view appears, until
    /// the returned task is cancelled.
    private func appear(
        in lifetime: FlowPresentationLifetime<FakeMarkupCanvas>,
        limit: CameraFlowPhotoLimit,
        making madeFlows: MadeFlows
    ) -> Task<Void, Never> {
        var changes = FlowConfigurationChanges()
        changes.append(.photoLimit(limit))
        let script = CameraFixtureScript(initialState: CameraFlowInitialState())
        return Task {
            await lifetime.run(script: script) {
                let callbacks = FlowCallbacks(onPreferencesChange: nil, onFinish: { _ in }, onCancel: {})
                let started = setup(changes: changes, callbacks: callbacks)
                let flow = madeFlows.harness.makeFlow(limit: started.configuration.photoLimit)
                madeFlows.flows.append(flow)
                return flow
            }
        }
    }

    #if os(macOS)
    /// A flow the program refuses: a configuration the modifiers made one no flow can honour, no receiver of the set or
    /// of the user's exit at the start, or a receiver the latest view lost by the time its event comes.
    enum RefusedStart: String, Sendable, Codable, CaseIterable, CustomTestStringConvertible {
        case limitBelowOne
        case locationOffWithProvider
        case jpegOutputUnderRAW
        case blankAlbum
        case noFinish
        case noCancel
        case finishLostWhileRunning
        case cancelLostWhileRunning

        func start() {
            var configuration = CameraFlowConfiguration()
            var changes = FlowConfigurationChanges()
            var callbacks = FlowCallbacks(onPreferencesChange: nil, onFinish: { _ in }, onCancel: {})
            var hasLocationProvider = false
            switch self {
            case .limitBelowOne: changes.append(.photoLimit(.maximum(0)))
            case .locationOffWithProvider:
                changes.append(.photoLocation(.off))
                hasLocationProvider = true
            case .jpegOutputUnderRAW:
                configuration.camera.photoFormat = .fixed(.raw)
                var output = CameraFlowOutput()
                output.format = .jpeg(quality: 0.8)
                changes.append(.output(output))
            case .blankAlbum:
                var saving = CameraFlowPhotoLibrarySaving()
                saving.destination = .album(named: " ")
                changes.append(.photoLibrarySaving(saving))
            case .noFinish: callbacks.onFinish = nil
            case .noCancel: callbacks.onCancel = nil
            case .finishLostWhileRunning, .cancelLostWhileRunning: break
            }
            let receivers = FlowReceivers()
            receivers.update(callbacks: callbacks, modifierCallbacks: FlowCallbacks())
            let started = FlowSetup(
                configuration: configuration,
                changes: changes,
                receivers: receivers,
                hasLocationProvider: hasLocationProvider
            )
            receivers.update(callbacks: FlowCallbacks(), modifierCallbacks: FlowCallbacks())
            switch self {
            case .finishLostWhileRunning: started.onFinish([])
            case .cancelLostWhileRunning: started.onCancel()
            default: break
            }
        }

        var testDescription: String {
            rawValue
        }
    }

    @Test(
        "A configuration no flow can honour, or an event without a receiver, stops the program",
        arguments: RefusedStart.allCases
    )
    func refusedStart(refused: RefusedStart) async {
        await #expect(processExitsWith: .failure) { [refused] in
            refused.start()
        }
    }
    #endif
}
