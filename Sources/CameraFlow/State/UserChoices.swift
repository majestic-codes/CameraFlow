//
//  UserChoices.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the user chose among the settings the user may change, as the flow remembers it and as it tells the app.
///
/// The flow opens with `reported`: what the app passed, and what the flow remembers for everything the app did not
/// pass. Only a change the user makes is recorded, so a value the camera cannot honour, which the flow takes as
/// the nearest it can, stays as it was chosen. A recorded change goes to the memory, where the flow has one, and
/// to the app.
struct UserChoices {
    /// What the flow tells the app: the app's own stored preferences over the remembered ones, with every change
    /// of the user since.
    private(set) var reported: CameraFlowPreferences
    /// What the memory holds: what it held when the flow opened, with every change of the user since.
    private(set) var remembered: CameraFlowPreferences

    private let memory: PreferencesMemory?
    private let onChange: ((CameraFlowPreferences) -> Void)?

    init(
        preferences: CameraFlowPreferences,
        memory: PreferencesMemory?,
        onChange: ((CameraFlowPreferences) -> Void)?
    ) {
        let remembered = memory?.load() ?? CameraFlowPreferences()
        self.remembered = remembered
        reported = preferences.filled(from: remembered)
        self.memory = memory
        self.onChange = onChange
    }

    /// Whether saving to the photo library opens on: as the stored choice has it where the user may switch it, as
    /// the app has it otherwise.
    func opensLibrarySaving(_ saving: CameraFlowPhotoLibrarySaving) -> Bool {
        saving.isEnabled.resolved(with: reported.isPhotoLibrarySavingEnabled)
    }

    /// Takes what the user just chose, one value for every property that is not nil, remembers it and reports it.
    /// Nothing chosen is nothing to report.
    mutating func record(_ changes: CameraFlowPreferences) {
        guard changes != CameraFlowPreferences() else { return }
        remembered = changes.filled(from: remembered)
        reported = changes.filled(from: reported)
        memory?.store(remembered)
        onChange?(reported)
    }
}
