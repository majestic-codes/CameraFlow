//
//  CameraSessionModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation
import os

/// The camera that runs: the access it needs, its life in the flow, its start at a side, alone or with the other
/// camera in the circle, what it can do, why it does not run and why it is paused. While it changes, the pictures on
/// screen hold a still of the camera that ran.
@MainActor
@Observable
final class CameraSessionModel {
    /// Lenses and zoom range of the running camera, nil until it has started.
    private(set) var capabilities: CameraCapabilities?
    /// What the running camera can do for photos, nil until it has started.
    private(set) var photoCapabilities: PhotoCaptureCapabilities?
    private(set) var failure: CameraFailure?
    /// Set while the session that runs is interrupted, for example by a call. Captures fail with `.interrupted`
    /// meanwhile.
    private(set) var interruption: CameraInterruption?
    /// Whether the back and the front camera run together, the one at `position` in the viewfinder and the other
    /// in its circle.
    private(set) var isDualCameraOn = false
    /// Where the camera is in its life in the flow. Only an active camera is changed or started again.
    private(set) var life = CameraLife.waiting

    /// The covers of the pictures on screen, which hold a still over them while a camera that ran gives way to
    /// another one or to the pair.
    @ObservationIgnored let pictureCovers: CameraPictureCovers
    /// The sides of the device that have a camera, the back first.
    @ObservationIgnored let cameraPositions: [CameraPosition]

    @ObservationIgnored private let service: any CameraService

    private static let logger = Logger.camera("CameraSessionModel")

    init(service: any CameraService, pictureCovers: CameraPictureCovers) {
        self.service = service
        self.pictureCovers = pictureCovers
        cameraPositions = service.cameraPositions
    }

    /// The side of the camera that runs. Before any has started it is the back, or the front on a device whose only
    /// camera is there.
    var position: CameraPosition {
        capabilities?.position ?? cameraPositions.first ?? .back
    }

    /// Whether the device has a camera on both sides, so there is one to flip to.
    var isFlipOffered: Bool {
        cameraPositions.count > 1
    }

    /// Whether the flow uses the camera now: its access was granted and it is neither stopped nor closed, also while
    /// it fails or is paused. Only then is it flipped or switched to the pair and back, which starts a camera that
    /// failed again.
    var isActive: Bool {
        life == .active
    }

    /// Whether the camera runs and takes what the user does on it: it is active and runs, without a failure and
    /// without a pause. The shutter, the capture buttons and the touches on the viewfinder act only then.
    var isRunning: Bool {
        isActive && capabilities != nil && failure == nil && interruption == nil
    }

    /// A preview of what the camera sees, for the viewfinder.
    func makePreview() -> any CameraPreview {
        service.makePreview()
    }

    /// A preview of the camera in the circle of the pair.
    func makeCirclePreview() -> any CameraPreview {
        service.makeCirclePreview()
    }

    // MARK: - Life

    /// Asks for camera access, and makes the camera active when it is granted. Returns whether the camera may be
    /// used. A refusal becomes the failure: the user's own as denied, a device policy's as restricted. A device
    /// with no camera is not asked, and its failure is the missing camera. A camera refused or closed meanwhile is
    /// not started.
    func requestAccess() async -> Bool {
        guard life == .waiting else { return false }
        guard service.hasCamera else {
            refuse(with: .unavailable(.noCamera))
            return false
        }
        switch await service.requestAuthorization() {
        case .authorized:
            guard life == .waiting else { return false }
            life = .active
            return true
        case .denied:
            refuse(with: .accessDenied)
        case .restricted:
            refuse(with: .accessRestricted)
        }
        return false
    }

    private func refuse(with failure: CameraFailure) {
        self.failure = failure
        if life == .waiting {
            life = .refused
        }
    }

    /// The flow stopped the camera on purpose. Its pause goes with the session: a camera started again under a pause
    /// that lasts reports it anew.
    func cameraStopped() {
        if life == .active {
            life = .stopped
        }
        interruption = nil
    }

    /// Lets a camera stopped on purpose start again, and returns whether it was stopped so.
    func cameraResumed() -> Bool {
        guard life == .stopped else { return false }
        life = .active
        return true
    }

    /// The flow closed the camera for good.
    func cameraClosed() {
        life = .closed
        interruption = nil
    }

    // MARK: - Starting

    /// Starts the camera at a position, or switches to it, and returns what it can do. A camera that cannot start
    /// becomes the failure, leaves the capabilities of the previous one and returns nil. The pause of a pair that
    /// gives way goes with its session.
    func startCamera(at position: CameraPosition) async -> CameraCapabilities? {
        coverRunningPicture()
        defer { pictureCovers.uncoverPictures() }
        if isDualCameraOn {
            interruption = nil
        }
        do {
            let started = try await service.start(position: position)
            capabilities = started
            photoCapabilities = service.photoCapabilities
            failure = nil
            isDualCameraOn = false
            return started
        } catch {
            Self.logger.error("The camera cannot start: \(String(describing: error), privacy: .public)")
            failure = .unavailable(Self.startError(error))
            return nil
        }
    }

    /// Starts the back and the front camera together with the one at `main` in the viewfinder, or swaps the two of
    /// a pair that runs, and returns what the one in the viewfinder can do. A pair that cannot start throws and
    /// changes nothing: the caller starts a single camera again, since the one that ran was let go. The pause of a
    /// single camera that gives way goes with its session.
    func startDualCamera(main: CameraPosition) async throws(CameraServiceError) -> CameraCapabilities {
        coverRunningPicture()
        defer { pictureCovers.uncoverPictures() }
        if !isDualCameraOn {
            interruption = nil
        }
        let started: CameraCapabilities
        do {
            started = try await service.startDualCamera(main: main)
        } catch {
            Self.logger.error("The dual camera cannot start: \(String(describing: error), privacy: .public)")
            throw Self.startError(error)
        }
        capabilities = started
        photoCapabilities = service.photoCapabilities
        failure = nil
        isDualCameraOn = true
        return started
    }

    /// Covers the pictures of a camera that has run, before it changes. The first start has no picture to cover.
    private func coverRunningPicture() {
        if capabilities != nil {
            pictureCovers.coverPictures()
        }
    }

    private static func startError(_ error: any Error) -> CameraServiceError {
        guard let serviceError = error as? CameraServiceError else {
            return .cannotUseCamera(String(describing: error))
        }
        return serviceError
    }

    // MARK: - What the camera reports

    func interrupted(by reason: CameraInterruption) {
        interruption = reason
    }

    func interruptionEnded() {
        interruption = nil
    }

    /// The session stopped with an error and has to be started again.
    func stopped() {
        failure = .stopped
    }
}
