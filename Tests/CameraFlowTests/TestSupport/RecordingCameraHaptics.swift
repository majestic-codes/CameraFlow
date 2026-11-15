//
//  RecordingCameraHaptics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

/// Haptics that only remember what the model asked them to play and to ready.
@MainActor
final class RecordingCameraHaptics: CameraHaptics {
    private(set) var events: [CameraHapticEvent] = []
    /// The haptics readied ahead of their event, in order.
    private(set) var prepared: [CameraHapticEvent] = []

    func play(_ event: CameraHapticEvent) {
        events.append(event)
    }

    func prepare(for event: CameraHapticEvent) {
        prepared.append(event)
    }

    func removeAll() {
        events.removeAll()
    }
}
