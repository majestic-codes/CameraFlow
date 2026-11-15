//
//  PreferenceStore.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Where the flow keeps what the user chose between openings, as bytes under a key.
protocol PreferenceStore {

    func data(forKey key: String) -> Data?
    /// Stores the bytes under the key, or removes the key with nil.
    func set(_ data: Data?, forKey key: String)
}
