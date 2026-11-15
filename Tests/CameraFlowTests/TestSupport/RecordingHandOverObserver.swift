//
//  RecordingHandOverObserver.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

/// An observer of a set's hand-overs that records what it heard and what it was asked, in order. It answers that a
/// set reaches someone unless the test says otherwise.
@MainActor
final class RecordingHandOverObserver: PhotoSetHandOverObserver {
    enum Event: Equatable {
        case began
        /// The set asked whether it reaches anyone.
        case asked
        case deleted
        case ended
    }

    private(set) var events: [Event] = []
    /// What the observer answers when the set asks whether it reaches anyone.
    var isReceiving = true

    func handOverBegan() {
        events.append(.began)
    }

    var receivesSets: Bool {
        events.append(.asked)
        return isReceiving
    }

    func setDeleted() {
        events.append(.deleted)
    }

    func handOverEnded() {
        events.append(.ended)
    }
}
