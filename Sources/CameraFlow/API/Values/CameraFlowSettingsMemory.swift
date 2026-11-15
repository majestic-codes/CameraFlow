//
//  CameraFlowSettingsMemory.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Whether the flow remembers the user's choices between openings, and where. Group 1 of ``CameraFlowConfiguration``.
///
/// The flow itself remembers what the user chose among the adjustable settings of group 2: flash, Live Photo, aspect
/// ratio, timer, format, the second camera's circle, the quality of the photos and saving to the photo
/// library. The next flow opens with them, as the stock Camera's Preserve Settings do, unless the app passes its
/// own value in ``CameraFlowConfiguration/preferences``, which goes first. Exposure bias, zoom and focus are not
/// remembered, like the stock camera. A setting the app fixed is never remembered and never changed by a remembered
/// value, and a remembered value the camera cannot honour is resolved as the panel resolves it, without touching
/// what is remembered: a circle remembered on opens off on a device that cannot run two cameras. A remembered value
/// that is not one of its setting's values reads as never chosen, and the log says so.
///
/// An app that keeps the choices itself takes ``off`` and passes what the flow reported back in
/// ``CameraFlowConfiguration/preferences``: see ``CameraFlowPreferences``.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`.
public enum CameraFlowSettingsMemory: Sendable, Hashable {
    /// Nothing is remembered: every flow opens with the app's values and the preferences the app passed.
    case off
    /// One value under one key in `UserDefaults`: the standard defaults, or the suite named, with the key prefix.
    /// The default: the standard defaults with the prefix `CameraFlow.`.
    ///
    /// A suite is one `UserDefaults(suiteName:)` opens, such as the identifier of an app group. The flow never
    /// falls back to the standard defaults for a suite it cannot open: creating the flow with one stops the program.
    /// `UserDefaults` opens no suite named after the app's own bundle identifier or the global domain, and an empty
    /// name is no suite.
    case userDefaults(suiteName: String? = nil, keyPrefix: String = "CameraFlow.")

    /// A suite `UserDefaults` does not open.
    struct UnusableSuite: Error, Equatable {
        let suiteName: String

        var message: String {
            "CameraFlowSettingsMemory.userDefaults cannot open the suite \"\(suiteName)\": "
                + "a suite is not empty, not the app's bundle identifier and not the global domain"
        }
    }

    /// The defaults the memory keeps its value in, nil for a flow that forgets. Throws for a suite that cannot be
    /// opened.
    func openDefaults() throws(UnusableSuite) -> UserDefaults? {
        switch self {
        case .off:
            return nil
        case let .userDefaults(suiteName, _):
            guard let suiteName else { return .standard }
            guard !suiteName.isEmpty, let defaults = UserDefaults(suiteName: suiteName) else {
                throw UnusableSuite(suiteName: suiteName)
            }
            return defaults
        }
    }

    /// The defaults the memory keeps its value in, nil for a flow that forgets. Stops the program on a suite that
    /// cannot be opened.
    /// - Precondition: a suite name is one `UserDefaults(suiteName:)` opens.
    var defaults: UserDefaults? {
        do {
            return try openDefaults()
        } catch {
            preconditionFailure(error.message)
        }
    }

    /// Stops the program on a memory no flow can keep.
    /// - Precondition: a suite name is one `UserDefaults(suiteName:)` opens.
    func validate() {
        _ = defaults
    }
}
