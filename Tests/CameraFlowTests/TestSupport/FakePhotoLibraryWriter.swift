//
//  FakePhotoLibraryWriter.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os
@testable import CameraFlow

/// A photo library that records what is asked of it: the access requested, the photos added and the album they
/// went into. Like Photos it keeps one answer for each access level: the one the test set, then the one a request
/// gives while that level is undecided, and a request of a decided level returns its standing answer. It fails a
/// save where the test tells it to, and drops the drawings where the test tells it to, as Photos does when it cannot
/// take the edit. With a gate it saves only once the gate has opened, and with an authorization gate a request is
/// answered only once that gate has opened.
final class FakePhotoLibraryWriter: PhotoLibraryWriter, Sendable {
    struct Addition: Equatable {
        let entry: PhotoLibraryEntry
        let albumName: String?
    }

    private struct State {
        var addOnlyAuthorization: PhotoLibraryAuthorization
        var readWriteAuthorization: PhotoLibraryAuthorization
        let grantedOnRequest: PhotoLibraryAuthorization
        var requestedAccess: [PhotoLibraryAccess] = []
        var additions: [Addition] = []
        var failure: CameraFlowPhotoLibraryError?
        var dropsDrawings = false
        var nextAssetNumber = 1

        subscript(access: PhotoLibraryAccess) -> PhotoLibraryAuthorization {
            get {
                switch access {
                case .addOnly: addOnlyAuthorization
                case .readWrite: readWriteAuthorization
                }
            }
            set {
                switch access {
                case .addOnly: addOnlyAuthorization = newValue
                case .readWrite: readWriteAuthorization = newValue
                }
            }
        }
    }

    private let state: OSAllocatedUnfairLock<State>
    private let gate: CallGate?
    private let authorizationGate: CallGate?

    /// A library whose every access level stands at `authorization`, and whose user answers a request with
    /// `grantedOnRequest`.
    init(
        authorization: PhotoLibraryAuthorization = .notDetermined,
        grantedOnRequest: PhotoLibraryAuthorization = .authorized,
        gate: CallGate? = nil,
        authorizationGate: CallGate? = nil
    ) {
        let initialState = State(
            addOnlyAuthorization: authorization,
            readWriteAuthorization: authorization,
            grantedOnRequest: grantedOnRequest
        )
        state = OSAllocatedUnfairLock(initialState: initialState)
        self.gate = gate
        self.authorizationGate = authorizationGate
    }

    /// The access levels the library was asked for, in order.
    var requestedAccess: [PhotoLibraryAccess] {
        state.withLock(\.requestedAccess)
    }

    /// Every asset added, with the album it went into.
    var additions: [Addition] {
        state.withLock(\.additions)
    }

    /// Makes every save from now on fail with the error.
    func failSaves(with failure: CameraFlowPhotoLibraryError) {
        state.withLock { $0.failure = failure }
    }

    /// Makes every save from now on create its asset without the drawing it was given.
    func dropDrawings() {
        state.withLock { $0.dropsDrawings = true }
    }

    func authorizationStatus(for access: PhotoLibraryAccess) -> PhotoLibraryAuthorization {
        state.withLock { $0[access] }
    }

    /// Records the request at once and answers it once the authorization gate has opened: with the user's answer
    /// where the level is still undecided, with the standing answer otherwise.
    func requestAuthorization(for access: PhotoLibraryAccess) async -> PhotoLibraryAuthorization {
        state.withLock { $0.requestedAccess.append(access) }
        await authorizationGate?.pass()
        return state.withLock { state in
            if state[access] == .notDetermined {
                state[access] = state.grantedOnRequest
            }
            return state[access]
        }
    }

    func add(
        _ entry: PhotoLibraryEntry,
        toAlbumNamed albumName: String?
    ) async throws(CameraFlowPhotoLibraryError) -> CameraFlowPhotoLibraryAsset {
        await gate?.pass()
        let outcome: Result<CameraFlowPhotoLibraryAsset, CameraFlowPhotoLibraryError> = state.withLock { state in
            if let failure = state.failure {
                return .failure(failure)
            }
            state.additions.append(Addition(entry: entry, albumName: albumName))
            defer { state.nextAssetNumber += 1 }
            let isMissingDrawing = state.dropsDrawings && entry.markedUpFileURL != nil
            let asset = CameraFlowPhotoLibraryAsset(
                localIdentifier: "asset-\(state.nextAssetNumber)",
                isMissingDrawing: isMissingDrawing
            )
            return .success(asset)
        }
        return try outcome.get()
    }
}

extension CaptureTestSupport {

    /// Saving to the library, switched on or off, over a fake library that grants access when asked.
    @MainActor
    static func makeLibrarySaving(
        isOn: Bool = true,
        isUserAdjustable: Bool = true,
        destination: CameraFlowPhotoLibrarySaving.Destination = .library,
        moment: CameraFlowPhotoLibrarySaving.Moment = .whenSetAccepted,
        writer: FakePhotoLibraryWriter = FakePhotoLibraryWriter()
    ) -> PhotoLibrarySavingModel {
        var saving = CameraFlowPhotoLibrarySaving()
        saving.destination = destination
        saving.moment = moment
        saving.isEnabled = CameraFlowSetting(isOn, isUserAdjustable: isUserAdjustable)
        return PhotoLibrarySavingModel(saving: saving, isOn: isOn, writer: writer)
    }
}
