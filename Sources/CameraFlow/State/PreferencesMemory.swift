//
//  PreferencesMemory.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os

/// Reads and writes what the user chose among the settings of group 2 in a preference store, as one
/// `CameraFlowPreferences` under one versioned key.
///
/// The stored bytes are outside the flow's control. A property whose value is not one of its values reads as nil,
/// and is logged. A value that is not a record at all (a damaged store) is discarded, logged once, and the flow opens
/// with the app's values. These are the places where a decoding error is not a failure of this code.
struct PreferencesMemory {
    let store: any PreferenceStore
    let keyPrefix: String

    private static let logger = Logger.camera("PreferencesMemory")
    /// The version of the stored value's shape: a new version with another key leaves the old value behind.
    private static let keySuffix = "preferences.v1"

    var key: String {
        keyPrefix + Self.keySuffix
    }

    /// The remembered choices, or none when nothing is stored or the stored value does not decode.
    func load() -> CameraFlowPreferences {
        guard let data = store.data(forKey: key) else {
            return CameraFlowPreferences()
        }
        do {
            let remembered = try JSONDecoder().decode(RememberedPreferences.self, from: data)
            if !remembered.droppedKeys.isEmpty {
                let keys = remembered.droppedKeys.joined(separator: ", ")
                Self.logger.error("Remembered preferences of no known value, dropped: \(keys, privacy: .public)")
            }
            return remembered.preferences
        } catch {
            let reason = String(describing: error)
            Self.logger.error("The remembered preferences do not decode, dropped: \(reason, privacy: .public)")
            store.set(nil, forKey: key)
            return CameraFlowPreferences()
        }
    }

    /// Writes the choices, replacing what was remembered.
    func store(_ preferences: CameraFlowPreferences) {
        do {
            store.set(try JSONEncoder().encode(preferences), forKey: key)
        } catch {
            let reason = String(describing: error)
            Self.logger.error("The preferences cannot be remembered: \(reason, privacy: .public)")
        }
    }
}

/// Remembered preferences as they decode, with the properties whose stored value is not one of theirs.
struct RememberedPreferences: Decodable {
    let preferences: CameraFlowPreferences
    /// The keys of the properties that read as nil for a value of no known kind.
    let droppedKeys: [String]

    init(from decoder: any Decoder) throws {
        var droppedKeys: [String] = []
        preferences = try CameraFlowPreferences(from: decoder, droppedKeys: &droppedKeys)
        self.droppedKeys = droppedKeys
    }
}
