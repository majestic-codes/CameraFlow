//
//  SimulatedPhotoLibrary.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os

/// A photo library with no Photos behind it, for a flow over the simulated camera: it is granted, at once or when
/// asked, takes every photo with its drawing and keeps none.
final class SimulatedPhotoLibrary: PhotoLibraryWriter {
    private struct State {
        var isAuthorizationDetermined: Bool
        var assetCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(isAuthorizationDetermined: Bool) {
        state = OSAllocatedUnfairLock(initialState: State(isAuthorizationDetermined: isAuthorizationDetermined))
    }

    func authorizationStatus(for access: PhotoLibraryAccess) -> PhotoLibraryAuthorization {
        state.withLock(\.isAuthorizationDetermined) ? .authorized : .notDetermined
    }

    func requestAuthorization(for access: PhotoLibraryAccess) async -> PhotoLibraryAuthorization {
        state.withLock { $0.isAuthorizationDetermined = true }
        return .authorized
    }

    func add(
        _ entry: PhotoLibraryEntry,
        toAlbumNamed albumName: String?
    ) async throws(CameraFlowPhotoLibraryError) -> CameraFlowPhotoLibraryAsset {
        let number = state.withLock { state in
            state.assetCount += 1
            return state.assetCount
        }
        return CameraFlowPhotoLibraryAsset(localIdentifier: "simulated-asset-\(number)")
    }
}
