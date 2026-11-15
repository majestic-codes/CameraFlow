//
//  CameraFlowModifierHostingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import CameraFlow

/// The SwiftUI modifiers of the flow through a real environment: views hosted in a window, the flow of a presentation
/// started by `CameraFlowView` itself, over the simulated camera.
@MainActor
@Suite("The SwiftUI modifiers of the flow in a hosted view", .serialized, .timeLimit(.minutes(1)))
struct CameraFlowModifierHostingTests {
    /// What the probes saw and which closures were called.
    @MainActor
    private final class Report {
        var changes = FlowConfigurationChanges()
        var callbacks = FlowCallbacks()
        var names: [String] = []
    }

    /// Reads the modifiers of the flow in its environment, as `CameraFlowView` does.
    private struct EnvironmentProbe: View {
        @Environment(\.flowConfigurationChanges) private var changes
        @Environment(\.flowModifierCallbacks) private var callbacks
        let report: Report

        var body: some View {
            report.changes = changes
            report.callbacks = callbacks
            return Color.clear
        }
    }

    /// A configuration whose flow opens on the simulated camera without asking for anything.
    private static var quietConfiguration: CameraFlowConfiguration {
        var configuration = CameraFlowConfiguration()
        configuration.onboarding = .off
        configuration.photoLocation = .off
        configuration.photoLimit = .maximum(4)
        return configuration
    }

    /// A window that shows the view.
    private func show<Content: View>(_ view: Content) -> (window: UIWindow, host: UIHostingController<Content>) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return (window, host)
    }

    /// Lets SwiftUI and the run loop take a turn.
    private func pump(milliseconds: Int = 100) async throws {
        try await Task.sleep(for: .milliseconds(milliseconds))
    }

    /// Waits for a condition the hosted views reach on their own, at most a few seconds.
    private func wait(until condition: () -> Bool) async throws {
        for _ in 0..<100 where condition() == false {
            try await pump(milliseconds: 50)
        }
        #expect(condition())
    }

    /// The accessibility languages the hosted flows set, from their scopes in the window.
    private func spokenLanguages(in view: UIView) -> [String?] {
        let own = (view as? AccessibilityLanguageView).map { [$0.language] } ?? []
        return own + view.subviews.flatMap(spokenLanguages(in:))
    }

    /// A flow of a presentation, created with a cancel of its own, under modifiers that name `owner`.
    private func presentedFlow(
        owner: String,
        limit: Int,
        language: String,
        lifetime: FlowPresentationLifetime<EmbeddedMarkupCanvas>,
        report: Report
    ) -> PresentedFlow<AnyView> {
        let view = CameraFlowView(
            configuration: Self.quietConfiguration,
            onFinish: { _ in report.names.append("\(owner) init finish") },
            onCancel: { report.names.append("\(owner) init cancel") }
        )
        .cameraFlowPhotoLimit(.maximum(limit))
        .cameraFlowLibraryPickerEnabled(false)
        .cameraFlowLanguage(.specific(Locale.Language(identifier: language)))
        .onCameraFlowFinish { _ in report.names.append("\(owner) finish") }
        return PresentedFlow(content: AnyView(view), presentation: lifetime)
    }

    @Test("The modifier nearest to the view wins through the environment, property by property and event by event")
    func nearestWins() async throws {
        let report = Report()
        let view = VStack {
            EnvironmentProbe(report: report)
                .cameraFlowPhotoLimit(.maximum(2))
                .onCameraFlowFinish { _ in report.names.append("inner finish") }
        }
        .cameraFlowPhotoLimit(.maximum(20))
        .cameraFlowLanguage(.specific(Locale.Language(identifier: "uk")))
        .onCameraFlowFinish { _ in report.names.append("outer finish") }
        .onCameraFlowCancel { report.names.append("outer cancel") }
        let (window, _) = show(view)
        try await pump()
        let applied = report.changes.applied(to: CameraFlowConfiguration())
        #expect(applied.photoLimit == .maximum(2))
        #expect(applied.language == .specific(Locale.Language(identifier: "uk")))
        report.callbacks.onFinish?([])
        report.callbacks.onCancel?()
        #expect(report.names == ["inner finish", "outer cancel"])
        #expect(report.callbacks.onPreferencesChange == nil)
        window.isHidden = true
    }

    @Test("The flow starts with the modifiers of its view and keeps its configuration when the view is created again")
    func configurationReadOnce() async throws {
        let report = Report()
        let lifetime = FlowPresentationLifetime<EmbeddedMarkupCanvas>()
        let first = presentedFlow(owner: "first", limit: 2, language: "uk", lifetime: lifetime, report: report)
        let (window, host) = show(first)
        try await wait { lifetime.screen != nil }
        let flow = try #require(lifetime.screen?.flow)
        #expect(flow.photoSet.limit == .maximum(2))
        #expect(flow.isLibraryPickerEnabled == false)

        host.rootView = presentedFlow(owner: "second", limit: 7, language: "de", lifetime: lifetime, report: report)
        host.view.layoutIfNeeded()
        try await pump(milliseconds: 300)
        #expect(lifetime.screen?.flow === flow)
        #expect(flow.photoSet.limit == .maximum(2))
        window.isHidden = true
        lifetime.end()
    }

    @Test("The texts follow the language of the latest view, from the configuration or a modifier")
    func languageFollowsLatest() async throws {
        let report = Report()
        let lifetime = FlowPresentationLifetime<EmbeddedMarkupCanvas>()
        let first = presentedFlow(owner: "first", limit: 2, language: "uk", lifetime: lifetime, report: report)
        let (window, host) = show(first)
        try await wait { lifetime.screen != nil }
        #expect(spokenLanguages(in: host.view) == ["uk"])

        host.rootView = presentedFlow(owner: "second", limit: 2, language: "de", lifetime: lifetime, report: report)
        host.view.layoutIfNeeded()
        try await pump(milliseconds: 300)
        #expect(spokenLanguages(in: host.view) == ["de"])
        window.isHidden = true
        lifetime.end()
    }

    @Test("The flow calls the closures of the latest view, the initializer's and the modifiers'")
    func latestClosures() async throws {
        let report = Report()
        let lifetime = FlowPresentationLifetime<EmbeddedMarkupCanvas>()
        let first = presentedFlow(owner: "first", limit: 2, language: "uk", lifetime: lifetime, report: report)
        let (window, host) = show(first)
        try await wait { lifetime.screen != nil }
        let flow = try #require(lifetime.screen?.flow)

        host.rootView = presentedFlow(owner: "second", limit: 2, language: "uk", lifetime: lifetime, report: report)
        host.view.layoutIfNeeded()
        try await pump(milliseconds: 300)
        flow.requestExit()
        #expect(report.names == ["second init cancel"])
        window.isHidden = true
        lifetime.end()
    }

    /// The view that would present a cover under modifiers of its own. A test process has no app to present it in.
    private struct CoverPresenter: View {
        let owner: String
        let report: Report

        var body: some View {
            Color.clear
                .cameraFlowCover(isPresented: .constant(false)) {
                    CameraFlowView()
                }
                .cameraFlowPhotoLimit(.maximum(3))
                .cameraFlowLibraryPickerEnabled(false)
                .onCameraFlowCancel { report.names.append("\(owner) cancel") }
        }
    }

    @Test("The cover takes the modifiers around the view that presents it, with their latest closures")
    func coverTakesModifiers() async throws {
        let report = Report()
        let (window, host) = show(CoverPresenter(owner: "first", report: report))
        try await pump()
        let anchor = try #require(host.children.first as? CameraFlowCoverAnchor<CameraFlowView>)
        let applied = anchor.inheritedModifiers.changes.applied(to: CameraFlowConfiguration())
        #expect(applied.photoLimit == .maximum(3))
        #expect(applied.isLibraryPickerEnabled == false)
        anchor.inheritedModifiers.callbacks.onCancel?()

        host.rootView = CoverPresenter(owner: "second", report: report)
        host.view.layoutIfNeeded()
        try await pump()
        anchor.inheritedModifiers.callbacks.onCancel?()
        #expect(report.names == ["first cancel", "second cancel"])
        window.isHidden = true
    }

    /// The modifiers a presenting view had around it, with a cancel that names `owner`.
    private func inheritedModifiers(owner: String, report: Report) -> FlowModifierEnvironment {
        var modifiers = FlowModifierEnvironment()
        modifiers.changes.append(.photoLimit(.maximum(3)))
        modifiers.changes.append(.libraryPicker(isEnabled: false))
        modifiers.callbacks.onFinish = { _ in report.names.append("\(owner) finish") }
        modifiers.callbacks.onCancel = { report.names.append("\(owner) cancel") }
        return modifiers
    }

    @Test("A presented flow starts with the inherited modifiers under its content's, and calls the latest closures")
    func presentedFlowTakesInheritedModifiers() async throws {
        let report = Report()
        let content = AnyView(CameraFlowView(configuration: Self.quietConfiguration).cameraFlowPhotoLimit(.maximum(6)))
        let cover = PortraitHostingController(
            content: content,
            inheritedModifiers: inheritedModifiers(owner: "first", report: report)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = cover
        window.makeKeyAndVisible()
        try await wait { cover.presentation.screen != nil }
        let flow = try #require(cover.presentation.screen?.flow)
        #expect(flow.photoSet.limit == .maximum(6))
        #expect(flow.isLibraryPickerEnabled == false)

        cover.show(content, inheritedModifiers: inheritedModifiers(owner: "second", report: report))
        cover.view.layoutIfNeeded()
        try await pump(milliseconds: 300)
        flow.requestExit()
        #expect(report.names == ["second cancel"])
        cover.presentation.end()
        window.isHidden = true
    }

    @Test("A view without closures is created and laid out without its receivers before its flow starts")
    func creationWithoutReceivers() async throws {
        let host = UIHostingController(rootView: CameraFlowView())
        host.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        host.view.layoutIfNeeded()
        try await pump()
    }
}
#endif
