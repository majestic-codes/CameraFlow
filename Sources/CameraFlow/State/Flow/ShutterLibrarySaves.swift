//
//  ShutterLibrarySaves.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Observation

/// The saves of the camera photos saved to the photo library right after their shot: one per photo, running while
/// the user goes on, and what became of each once it ended.
@MainActor
@Observable
final class ShutterLibrarySaves {
    /// What became of the photos whose save ended, by photo.
    private(set) var results: [UUID: CameraFlowPhotoLibrarySave] = [:]
    @ObservationIgnored private var saves: [UUID: Task<CameraFlowPhotoLibrarySave, Never>] = [:]

    /// Saves a photo's camera files and calls `onEnd` with what became of them, with the app kept running in the
    /// background until the save has ended. A photo is saved once: a second call for it does nothing.
    func save(
        _ photo: FlowPhoto,
        to librarySaving: PhotoLibrarySavingModel,
        keptRunningBy backgroundWork: any BackgroundWork,
        onEnd: @escaping (CameraFlowPhotoLibrarySave) -> Void
    ) {
        let photoIdentifier = photo.id
        guard saves[photoIdentifier] == nil else { return }
        let entry = photo.libraryEntry(markedUpFileURL: nil)
        saves[photoIdentifier] = Task { [weak self] in
            let save = await backgroundWork.run(named: "CameraFlow library save") {
                await librarySaving.save(entry)
            }
            self?.results[photoIdentifier] = save
            onEnd(save)
            return save
        }
    }

    /// Whether the photo was saved, not only tried.
    func isSaved(_ photoIdentifier: UUID) -> Bool {
        guard case .saved = results[photoIdentifier] else { return false }
        return true
    }

    /// The save of a photo while it runs, nil for a photo never saved this way or whose save ended.
    func running(_ photoIdentifier: UUID) -> Task<CameraFlowPhotoLibrarySave, Never>? {
        guard results[photoIdentifier] == nil else { return nil }
        return saves[photoIdentifier]
    }

    /// What became of a photo saved this way, once its save ended, nil for a photo never saved this way.
    func result(of photoIdentifier: UUID) async -> CameraFlowPhotoLibrarySave? {
        await saves[photoIdentifier]?.value
    }
}
