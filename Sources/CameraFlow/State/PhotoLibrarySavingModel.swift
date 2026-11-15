//
//  PhotoLibrarySavingModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation
import os

/// Saving the camera's photos to the system photo library: whether it is on, and the access it needs and asks for
/// when first needed.
///
/// The photos are saved when the user accepts the set, or right after each shot where the app asks for it, one after
/// the other. The library is asked for access once per flow: in the introduction, when the user switches saving on
/// or, if neither happened, at the first photo saved, and the standing answer serves every later save. Switching on
/// fails openly: when access is refused the switch stays off, the caller is told why and `refusal` keeps it. A flow
/// that opens with saving on over a refused library says so from the start.
@MainActor
@Observable
final class PhotoLibrarySavingModel {
    /// Whether the next photo is saved.
    private(set) var isOn: Bool
    /// Why saving could not be switched on, or the library refused the access asked for ahead of the first save,
    /// until `clearRefusal()`.
    private(set) var refusal: CameraFlowPhotoLibrarySaveFailure?
    let destination: CameraFlowPhotoLibrarySaving.Destination
    /// When a camera photo is saved.
    let moment: CameraFlowPhotoLibrarySaving.Moment
    /// Whether the user may switch saving on and off.
    let isUserAdjustable: Bool

    @ObservationIgnored private let writer: any PhotoLibraryWriter
    @ObservationIgnored private var authorizationRequest: Task<PhotoLibraryAuthorization, Never>?
    /// The last save asked for, which the next one waits for: the album one save creates is the album the next finds.
    @ObservationIgnored private var lastSave: Task<CameraFlowPhotoLibrarySave, Never>?

    private static let logger = Logger.camera("PhotoLibrarySavingModel")

    init(saving: CameraFlowPhotoLibrarySaving, isOn: Bool, writer: any PhotoLibraryWriter) {
        destination = saving.destination
        moment = saving.moment
        isUserAdjustable = saving.isEnabled.isUserAdjustable
        self.isOn = isOn
        self.writer = writer
    }

    /// The access the destination needs.
    var access: PhotoLibraryAccess {
        switch destination {
        case .library: .addOnly
        case .album: .readWrite
        }
    }

    /// The name of the album the photos go into, nil for the library itself.
    var albumName: String? {
        guard case let .album(name) = destination else { return nil }
        return name
    }

    // MARK: - Switching

    /// Switches saving on, once the library grants the access, or off. Switching on under refused access leaves it
    /// off and keeps the refusal. Returns why saving could not be switched on, nil when the switch took effect.
    @discardableResult
    func setOn(_ isOn: Bool) async -> CameraFlowPhotoLibrarySaveFailure? {
        guard isOn else {
            self.isOn = false
            return nil
        }
        if let refusal = await accessRefusal() {
            self.isOn = false
            self.refusal = refusal
            return refusal
        }
        self.isOn = true
        return nil
    }

    /// Forgets why saving was refused last, once the user has gone on.
    func clearRefusal() {
        refusal = nil
    }

    /// Takes an answer the library had before the flow opened, without asking: saving that is on over a refused
    /// destination goes off where the user may switch it, and `refusal` keeps why, so the screen says it before any
    /// photo is taken. The user's choice is not recorded as off, so it comes back in a flow with access.
    func applyStandingRefusal() {
        let authorization = writer.authorizationStatus(for: access)
        guard isOn, authorization != .notDetermined, let standingRefusal = failure(for: authorization) else { return }
        turnOffWhereUserAdjustable()
        refusal = standingRefusal
    }

    // MARK: - Saving

    /// Saves the camera's files of a photo once the saves asked for before it have ended, and reports what became of
    /// it. A refused access of a switch the user owns turns saving off, so the switch shows the truth.
    func save(_ entry: PhotoLibraryEntry) async -> CameraFlowPhotoLibrarySave {
        let previous = lastSave
        let save = Task {
            _ = await previous?.value
            return await saveAfterPrevious(entry)
        }
        lastSave = save
        return await save.value
    }

    private func saveAfterPrevious(_ entry: PhotoLibraryEntry) async -> CameraFlowPhotoLibrarySave {
        if let refusal = await accessRefusal() {
            turnOffWhereUserAdjustable()
            return .failed(refusal)
        }
        do {
            let asset = try await writer.add(entry, toAlbumNamed: albumName)
            return .saved(asset)
        } catch {
            Self.logger.error("Cannot save the photo to the library: \(String(describing: error), privacy: .public)")
            return .failed(.libraryError(error))
        }
    }

    private func turnOffWhereUserAdjustable() {
        if isUserAdjustable {
            isOn = false
        }
    }

    // MARK: - Access

    /// Whether the library has yet to be asked for the access the destination needs.
    var isAccessUndetermined: Bool {
        writer.authorizationStatus(for: access) == .notDetermined
    }

    /// Whether the library refuses the access the destination needs in a way the user can lift in the app's page of
    /// Settings: access denied, or limited access for an album. Read from the library without asking it.
    var isRefusalLiftedInSettings: Bool {
        switch (writer.authorizationStatus(for: access), destination) {
        case (.denied, _), (.limited, .album): true
        case (.notDetermined, _), (.authorized, _), (.limited, .library), (.restricted, _): false
        }
    }

    /// Asks the library for the access ahead of the first save, where saving is on, and returns why the destination
    /// is out of reach, nil when it can be written to. A refused access is kept, and turns a switch the user owns
    /// off.
    func requestAccess() async -> CameraFlowPhotoLibrarySaveFailure? {
        guard isOn, let refusal = await accessRefusal() else { return nil }
        turnOffWhereUserAdjustable()
        self.refusal = refusal
        return refusal
    }

    /// Why the destination is out of reach, nil while it can be written to. Asks the user once when nothing is
    /// decided yet.
    private func accessRefusal() async -> CameraFlowPhotoLibrarySaveFailure? {
        var authorization = writer.authorizationStatus(for: access)
        if authorization == .notDetermined {
            authorization = await requestAuthorization()
        }
        return failure(for: authorization)
    }

    /// Why the destination is out of reach with the access, nil when it can be written to.
    private func failure(for authorization: PhotoLibraryAuthorization) -> CameraFlowPhotoLibrarySaveFailure? {
        switch (authorization, destination) {
        case (.authorized, _), (.limited, .library): nil
        case (.limited, .album): .limitedAccess
        case (.restricted, _): .accessRestricted
        case (.denied, _), (.notDetermined, _): .accessDenied
        }
    }

    /// One request serves every save that waits for the answer.
    private func requestAuthorization() async -> PhotoLibraryAuthorization {
        if let authorizationRequest {
            return await authorizationRequest.value
        }
        let request = Task { [writer, access] in
            await writer.requestAuthorization(for: access)
        }
        authorizationRequest = request
        let authorization = await request.value
        authorizationRequest = nil
        return authorization
    }
}
