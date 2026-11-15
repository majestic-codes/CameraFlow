//
//  FlowConfigurationChanges.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 15.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The properties of `CameraFlowConfiguration` that the SwiftUI modifiers of the flow set, in the order the
/// environment receives them: the modifier furthest from the view first. Applied in that order, a later change of a
/// property replaces an earlier one, so the modifier nearest to the view wins.
struct FlowConfigurationChanges: Sendable, Hashable {
    /// One property of the configuration and the value a modifier gives it.
    enum Change: Sendable, Hashable {
        case language(CameraFlowLanguage)
        case photoLimit(CameraFlowPhotoLimit)
        case libraryPicker(isEnabled: Bool)
        case photoLibrarySaving(CameraFlowPhotoLibrarySaving)
        case photoLocation(CameraFlowPhotoLocation)
        case photoDirection(CameraFlowPhotoDirection)
        case output(CameraFlowOutput)

        /// Sets the property to the value, as an assignment to the property does.
        func apply(to configuration: inout CameraFlowConfiguration) {
            switch self {
            case let .language(language): configuration.language = language
            case let .photoLimit(limit): configuration.photoLimit = limit
            case let .libraryPicker(isEnabled): configuration.isLibraryPickerEnabled = isEnabled
            case let .photoLibrarySaving(saving): configuration.photoLibrarySaving = saving
            case let .photoLocation(location): configuration.photoLocation = location
            case let .photoDirection(direction): configuration.photoDirection = direction
            case let .output(output): configuration.output = output
            }
        }
    }

    private var changes: [Change] = []

    /// Adds a change after the ones the modifiers further out made.
    mutating func append(_ change: Change) {
        changes.append(change)
    }

    /// The configuration with every change applied over it in order. A property no modifier set keeps its value.
    func applied(to configuration: CameraFlowConfiguration) -> CameraFlowConfiguration {
        changes.reduce(into: configuration) { changed, change in
            change.apply(to: &changed)
        }
    }
}
