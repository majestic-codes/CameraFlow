//
//  ExampleDefaults.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the app keeps in its standard defaults: the preferences the example stored and the flow's memory of the
/// user's settings.
enum ExampleDefaults {
    enum ResetError: Error {
        /// The app has no bundle identifier, which names its defaults.
        case noBundleIdentifier
    }

    /// Removes everything the app keeps in its standard defaults.
    static func removeAll() throws {
        guard let identifier = Bundle.main.bundleIdentifier else { throw ResetError.noBundleIdentifier }
        UserDefaults.standard.removePersistentDomain(forName: identifier)
    }
}
