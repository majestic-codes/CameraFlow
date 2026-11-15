//
//  FlowConfigurationChangesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("The properties the SwiftUI modifiers set over the configuration")
struct FlowConfigurationChangesTests {
    /// A configuration an app passes to the view, with properties of its own that no modifier sets.
    private static var base: CameraFlowConfiguration {
        var configuration = CameraFlowConfiguration()
        configuration.photoLimit = .maximum(3)
        configuration.completion = .afterOnePhoto
        configuration.camera.photoFormat = .fixed(.heif)
        configuration.onboarding = .off
        configuration.language = .specific(Locale.Language(identifier: "de"))
        return configuration
    }

    /// One modifier and the property it sets.
    enum Modifier: String, Sendable, CaseIterable, CustomTestStringConvertible {
        case language
        case photoLimit
        case libraryPicker
        case photoLibrarySaving
        case photoLocation
        case photoDirection
        case output

        var change: FlowConfigurationChanges.Change {
            switch self {
            case .language: .language(.specific(Locale.Language(identifier: "uk")))
            case .photoLimit: .photoLimit(.single)
            case .libraryPicker: .libraryPicker(isEnabled: false)
            case .photoLibrarySaving: .photoLibrarySaving(Self.changedSaving)
            case .photoLocation: .photoLocation(.appRequestsAccess)
            case .photoDirection: .photoDirection(.recorded)
            case .output: .output(Self.changedOutput)
            }
        }

        /// The configuration with the property assigned as an app assigns it.
        func assigned(over configuration: CameraFlowConfiguration) -> CameraFlowConfiguration {
            var assigned = configuration
            switch self {
            case .language: assigned.language = .specific(Locale.Language(identifier: "uk"))
            case .photoLimit: assigned.photoLimit = .single
            case .libraryPicker: assigned.isLibraryPickerEnabled = false
            case .photoLibrarySaving: assigned.photoLibrarySaving = Self.changedSaving
            case .photoLocation: assigned.photoLocation = .appRequestsAccess
            case .photoDirection: assigned.photoDirection = .recorded
            case .output: assigned.output = Self.changedOutput
            }
            return assigned
        }

        private static var changedSaving: CameraFlowPhotoLibrarySaving {
            var saving = CameraFlowPhotoLibrarySaving()
            saving.isEnabled = CameraFlowSetting(true)
            saving.destination = .album(named: "Field photos")
            saving.moment = .afterEachPhoto
            return saving
        }

        private static var changedOutput: CameraFlowOutput {
            var output = CameraFlowOutput()
            output.size = .standard
            output.format = .jpeg(quality: 0.8)
            output.metadata = .stripped
            return output
        }

        var testDescription: String {
            rawValue
        }
    }

    @Test("Without a modifier the configuration stays as the app passed it")
    func noChange() {
        #expect(FlowConfigurationChanges().applied(to: Self.base) == Self.base)
    }

    @Test("A modifier sets its property as an assignment does and leaves the others", arguments: Modifier.allCases)
    func oneChange(modifier: Modifier) {
        var changes = FlowConfigurationChanges()
        changes.append(modifier.change)
        let changed = changes.applied(to: Self.base)
        #expect(changed == modifier.assigned(over: Self.base))
        #expect(changed != Self.base)
    }

    @Test("The modifier nearest to the view wins over the ones further out")
    func nearestWins() {
        var changes = FlowConfigurationChanges()
        changes.append(.photoLimit(.maximum(9)))
        changes.append(.language(.system))
        changes.append(.photoLimit(.maximum(2)))
        let changed = changes.applied(to: Self.base)
        #expect(changed.photoLimit == .maximum(2))
        #expect(changed.language == .system)
    }

    @Test("Modifiers of different properties combine, over a base that keeps the rest")
    func combined() {
        var changes = FlowConfigurationChanges()
        for modifier in Modifier.allCases {
            changes.append(modifier.change)
        }
        let changed = changes.applied(to: Self.base)
        let assigned = Modifier.allCases.reduce(Self.base) { configuration, modifier in
            modifier.assigned(over: configuration)
        }
        #expect(changed == assigned)
        #expect(changed.completion == .afterOnePhoto)
        #expect(changed.camera.photoFormat == .fixed(.heif))
        #expect(changed.onboarding == .off)
    }

    @Test("The changes are one value: the same modifiers are equal, and others differ")
    func equality() {
        var first = FlowConfigurationChanges()
        first.append(.photoLimit(.single))
        var second = FlowConfigurationChanges()
        second.append(.photoLimit(.single))
        #expect(first == second)
        second.append(.photoDirection(.recorded))
        #expect(first != second)
    }
}
