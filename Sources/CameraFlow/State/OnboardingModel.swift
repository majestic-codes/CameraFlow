//
//  OnboardingModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Observation
import os

/// One screen of the introduction, named after the access its Continue button asks for.
enum OnboardingStep: Sendable, Equatable {
    case camera
    /// When-in-use access to the location, which the photos record.
    case location
    /// The access a save to the photo library needs, and whether the user may switch saving in the camera.
    case photoLibrary(access: PhotoLibraryAccess, isSavingUserAdjustable: Bool)
}

/// The introduction of a flow that opens before the user answered an access it needs: the step it shows, and the
/// system requests its Continue button brings.
///
/// The camera comes first and holds the camera back until it has an answer. A granted camera, at its step or
/// before the flow opened, is followed by the location, where the flow asks for it and it has not been asked for,
/// and then by the photo library, where the flow opens with saving on and the library has not been asked for yet.
/// Any other answer of the camera ends the introduction, and the camera says the rest itself. A flow that opens
/// with saving off asks for the library when the user switches saving on.
///
/// Without the introduction, the location is asked for right after the camera is granted, with no step.
///
/// The library is asked for through the saving of the flow, so a refusal is the saving's to act on: a switch the
/// user owns goes off, and the saving keeps why.
@MainActor
@Observable
final class OnboardingModel {
    /// The step on screen, nil when the introduction is over or was never due.
    private(set) var step: OnboardingStep?
    /// True while a system request is up, so its answer is not asked for twice.
    private(set) var isAsking = false

    @ObservationIgnored private let setting: CameraFlowOnboarding
    @ObservationIgnored private let service: any CameraService
    /// The location access of a flow that asks for it, nil for a flow that never does.
    @ObservationIgnored private let location: (any LocationAuthorizer)?
    /// The saving of a flow that saves to the photo library, nil for a flow that never does.
    @ObservationIgnored private let librarySaving: PhotoLibrarySavingModel?
    /// Whether the camera step is over, or was never due.
    @ObservationIgnored private var isCameraStepOver = false
    /// The tasks waiting for the camera step to end. A waiter cancelled on its own leaves the step as it is, so a
    /// later wait still waits for Continue.
    @ObservationIgnored private var cameraStepWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    private static let logger = Logger.camera("OnboardingModel")

    /// A device with no camera and a camera that was refused get no introduction. A camera granted before opens on
    /// the location step, or on the library step where the location step is not due.
    init(
        setting: CameraFlowOnboarding,
        service: any CameraService,
        location: (any LocationAuthorizer)?,
        librarySaving: PhotoLibrarySavingModel?
    ) {
        self.setting = setting
        self.service = service
        self.location = location
        self.librarySaving = librarySaving
        let isIntroduced = setting == .automatic && service.hasCamera
        if isIntroduced, !service.isAuthorizationDetermined {
            step = .camera
        } else {
            if isIntroduced, service.isAuthorized {
                step = Self.locationStep(location) ?? libraryStep
            }
            isCameraStepOver = true
        }
    }

    /// Returns once the camera step is over: at once when there is none, and when the calling task is cancelled.
    /// A cancelled wait does not end the step: the next one waits for Continue again.
    func waitForCameraStep() async {
        guard !isCameraStepOver else { return }
        let waiter = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if isCameraStepOver || Task.isCancelled {
                    continuation.resume()
                } else {
                    cameraStepWaiters[waiter] = continuation
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.cameraStepWaiters.removeValue(forKey: waiter)?.resume()
            }
        }
    }

    private func endCameraStep() {
        isCameraStepOver = true
        let waiters = cameraStepWaiters.values
        cameraStepWaiters = [:]
        waiters.forEach { $0.resume() }
    }

    /// The Continue button: asks the system for the access of the step and moves on with the answer.
    func proceed() async {
        guard let step, !isAsking else { return }
        isAsking = true
        defer { isAsking = false }
        switch step {
        case .camera:
            let authorization = await service.requestAuthorization()
            self.step = authorization == .authorized ? Self.locationStep(location) ?? libraryStep : nil
            endCameraStep()
        case .location:
            await askForLocation()
            self.step = libraryStep
        case .photoLibrary:
            await askForPhotoLibrary()
            self.step = nil
        }
    }

    /// Asks for the location in a flow without the introduction, once its camera is granted. Nothing happens where
    /// the introduction is on, where the flow does not ask, or once the location has an answer.
    func askForLocationWithoutIntroduction() async {
        guard setting == .off, Self.locationStep(location) != nil else { return }
        await askForLocation()
    }

    private func askForLocation() async {
        guard let location else { return }
        let answer = await location.requestAuthorization()
        Self.logger.info("The location was answered: \(String(describing: answer), privacy: .public)")
    }

    /// Asks through the saving, which turns a switch the user owns off and keeps the refusal when the library refuses.
    private func askForPhotoLibrary() async {
        guard let refusal = await librarySaving?.requestAccess() else { return }
        Self.logger.info("The photo library was refused: \(String(describing: refusal), privacy: .public)")
    }

    /// The step of the location, nil for a flow that does not ask for it and for a location that has an answer.
    private static func locationStep(_ location: (any LocationAuthorizer)?) -> OnboardingStep? {
        guard let location, location.authorization == .notDetermined else { return nil }
        return .location
    }

    /// The step of the photo library, nil for a flow that opens with saving off and for a library that has an
    /// answer.
    private var libraryStep: OnboardingStep? {
        guard let librarySaving, librarySaving.isOn, librarySaving.isAccessUndetermined else { return nil }
        return .photoLibrary(
            access: librarySaving.access,
            isSavingUserAdjustable: librarySaving.isUserAdjustable
        )
    }
}
