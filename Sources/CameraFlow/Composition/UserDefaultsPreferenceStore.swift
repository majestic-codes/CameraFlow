//
//  UserDefaultsPreferenceStore.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The flow's preferences in user defaults, as data under a key. The defaults are held, not extended, so the module
/// gives `UserDefaults` no conformance of its own.
struct UserDefaultsPreferenceStore: PreferenceStore {
    let defaults: UserDefaults

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        guard let data else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
