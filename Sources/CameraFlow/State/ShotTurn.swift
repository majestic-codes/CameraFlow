//
//  ShotTurn.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The place of one photo in the order of the shutter: the photo is processed and handed over once the photo fired
/// before it is handed over or has failed, and the photo fired after it waits for it in turn.
@MainActor
final class ShotTurn {
    /// The turn of the photo fired before this one, until this turn begins.
    private var previous: ShotTurn?
    private var isOver = false
    /// The turns that wait for this one to end.
    private var followers: [CheckedContinuation<Void, Never>] = []

    /// The turn after `previous`, the turn of the photo fired last. A turn after none, or after one that is over,
    /// begins at once.
    init(after previous: ShotTurn?) {
        self.previous = previous
    }

    /// Returns once the photo fired before this one, and with it every photo fired earlier, is handed over or has
    /// failed.
    func begin() async {
        guard let previous else { return }
        await previous.waitUntilOver()
        self.previous = nil
    }

    /// The photo of this turn is handed over or has failed, after its turn began: the photo fired after it goes on.
    func end() {
        isOver = true
        let waiting = followers
        followers = []
        waiting.forEach { $0.resume() }
    }

    private func waitUntilOver() async {
        guard !isOver else { return }
        await withCheckedContinuation { followers.append($0) }
    }
}
