//
//  ShutterModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Observation
import os

/// The shutter: the self-timer, the capture and the hand-over of the photos. `PhotoCameraModel` presses it with what
/// the photo is taken with.
///
/// It keeps up with quick taps as the stock camera does: a tap takes a photo as soon as the camera is ready for
/// another one, while the photos before it are still being taken, processed and handed over. The photos go through
/// their pipeline one at a time and reach the receiver in the order they were shot, and a photo that fails holds up
/// none after it.
@MainActor
@Observable
final class ShutterModel {
    /// Goes up by one with every photo the shutter fires: once the camera takes the photo, at the tap or at zero
    /// when the timer runs.
    private(set) var captureCount = 0
    /// How many photos are on their way, each from the tap the shutter took until the photo is handed over or fails,
    /// the countdown included.
    private(set) var photosInFlight = 0
    /// How ready the camera is to take another photo, as it said last. A camera that says nothing is ready.
    private(set) var readiness = CaptureReadiness.ready
    /// The tap whose shot has not reached the camera yet, nil when there is none: the room for its photo is read, its
    /// countdown runs or a change of the camera under way ends first.
    private var preparingPress: Int?

    @ObservationIgnored let countdown: PhotoCaptureCountdown
    @ObservationIgnored private let service: any CameraService
    @ObservationIgnored private let delivery: CaptureDelivery
    /// Decides whether the shutter may take another photo, nil when it always may.
    @ObservationIgnored private let admission: (any CaptureAdmission)?
    /// Keeps the camera from changing under a photo, and a photo from being taken while the camera changes.
    @ObservationIgnored private let changes: CameraChangeGate
    @ObservationIgnored private let storage: any StorageSpace
    /// Keeps the app running until a photo whose shutter fired is handed over.
    @ObservationIgnored private let backgroundWork: any BackgroundWork
    /// How many taps the shutter took, which numbers them.
    @ObservationIgnored private var pressCount = 0
    /// The turn of the photo fired last, which the next photo fired waits for before it is processed.
    @ObservationIgnored private var lastTurn: ShotTurn?

    /// The least room a photo is taken with: a 12 MP Apple ProRAW file of about 25 MB with the copies the flow
    /// writes beside it and its Live Photo movie, with room to spare. The stock camera's own threshold depends on the
    /// capture and is not public.
    nonisolated static let minimumFreeBytes: Int64 = 100_000_000

    private static let logger = Logger.camera("ShutterModel")

    init(
        service: any CameraService,
        delivery: CaptureDelivery,
        clock: any Clock<Duration>,
        admission: (any CaptureAdmission)?,
        changes: CameraChangeGate,
        storage: any StorageSpace,
        backgroundWork: any BackgroundWork
    ) {
        self.service = service
        self.delivery = delivery
        self.admission = admission
        self.changes = changes
        self.storage = storage
        self.backgroundWork = backgroundWork
        countdown = PhotoCaptureCountdown(clock: clock)
    }

    /// Whether a photo is on its way, the countdown included.
    var isCapturing: Bool {
        photosInFlight > 0
    }

    /// How many photos the camera was asked to take that are still on their way, each from the moment its shot fires
    /// until it is handed over or fails. A tap whose shot has not reached the camera, its countdown included, has no
    /// photo yet. The shutter takes no other tap while one prepares, so at most one tap of `photosInFlight` is that.
    var firedPhotosInFlight: Int {
        preparingPress == nil ? photosInFlight : photosInFlight - 1
    }

    /// Seconds left on the self-timer, nil while it does not run.
    var countdownSeconds: Int? {
        countdown.remainingSeconds
    }

    /// Whether the self-timer counts down.
    var isCountingDown: Bool {
        countdownSeconds != nil
    }

    /// Whether a tap takes no photo now, as the stock camera's shutter is inert then: the shot of the tap before has
    /// not reached the camera yet, or the camera is busy with the photos before. A camera that does not run is not
    /// busy: a tap then waits for the change of the camera under way, or fails as not running.
    var isBusy: Bool {
        guard preparingPress == nil else { return true }
        return switch readiness {
        case .notRunning, .ready: false
        case .notReadyMomentarily, .waitingForCapture, .waitingForProcessing: true
        }
    }

    /// Whether a tap does anything now: it takes a photo, or it stops the self-timer.
    var takesTap: Bool {
        isCountingDown || !isBusy
    }

    /// How the shutter shows that the camera is busy: not at all for a moment's wait, which would only distract.
    var busyIndication: ShutterBusyIndication {
        switch readiness {
        case .notRunning, .ready, .notReadyMomentarily: .unchanged
        case .waitingForCapture: .dimmed
        case .waitingForProcessing: .spinning
        }
    }

    /// The camera said how ready it is to take another photo.
    func cameraReadinessChanged(to readiness: CaptureReadiness) {
        self.readiness = readiness
    }

    /// Stops the self-timer; no photo is taken.
    func cancelCountdown() {
        countdown.cancel()
    }

    /// The shutter, with the self-timer of the photo. With the timer on it counts down first and fires at zero; a tap
    /// during the countdown cancels it, as in the stock camera. A tap while the shutter is busy is ignored, and a
    /// device without the room for a photo takes none, as the stock camera refuses it.
    ///
    /// `began` runs once the tap starts a capture, before the countdown. `shot` gives what the photo is taken with
    /// when the shutter fires, once a change of the camera under way is over. The photo goes through its pipeline once
    /// every photo fired before it is handed over or has failed, then it is handed over, and the app keeps running for
    /// it in the background. A capture that finishes after the delivery has closed is deleted instead. A photo taken
    /// without a part that failed, its Live Photo movie or its circle, is handed over all the same. Returns why the tap
    /// took no photo, the refusal of the set, the missing room or the failure of the capture, or what the photo it
    /// handed over lacks, and nil when there is nothing to say.
    func capture(
        timer: CameraFlowTimer,
        began: () -> Void,
        shot: () throws(CameraServiceError) -> PhotoShot
    ) async -> ShutterReport? {
        if countdown.isRunning {
            countdown.cancel()
            return nil
        }
        guard !isBusy else { return nil }
        if let refusal = admission?.captureRefusal(photosInFlight: photosInFlight) {
            return .failed(refusal)
        }
        let press = beginPress()
        let report = await take(press, timer: timer, began: began, shot: shot)
        end(press)
        return report
    }

    /// Takes a tap on: its photo is on its way from now on, and the shutter takes no other tap until its shot reaches
    /// the camera. Returns the number of the tap.
    private func beginPress() -> Int {
        pressCount += 1
        preparingPress = pressCount
        photosInFlight += 1
        return pressCount
    }

    /// The shot of the tap has reached the camera, or the tap takes no photo: the shutter takes the next tap once the
    /// camera is ready for it.
    private func release(_ press: Int) {
        if preparingPress == press {
            preparingPress = nil
        }
    }

    /// The photo of the tap is handed over or has failed, or the tap took none.
    private func end(_ press: Int) {
        release(press)
        photosInFlight -= 1
    }

    /// Takes the photo of a tap the shutter took: once the room for it is read and the countdown is over.
    private func take(
        _ press: Int,
        timer: CameraFlowTimer,
        began: () -> Void,
        shot: () throws(CameraServiceError) -> PhotoShot
    ) async -> ShutterReport? {
        guard await hasRoomForPhoto() else {
            return .failed(.notEnoughStorage)
        }
        began()
        if timer != .off {
            guard await countdown.run(seconds: timer.rawValue) else { return nil }
        }
        return await backgroundWork.run(named: "CameraFlow photo") {
            await fire(press, shot)
        }
    }

    /// Whether the volume has the room for another photo. A volume that does not say lets the photo be taken, and
    /// its write says what fails.
    private func hasRoomForPhoto() async -> Bool {
        do {
            return try await storage.availableBytes() >= Self.minimumFreeBytes
        } catch {
            Self.logger.error("The free space cannot be read", cause: error)
            return true
        }
    }

    /// Fires the shot once the changes of the camera asked for before are over, and hands its photo over in its turn.
    private func fire(_ press: Int, _ makeShot: () throws(CameraServiceError) -> PhotoShot) async -> ShutterReport? {
        let fired: FiredShot
        do {
            fired = try await changes.capture {
                try await shoot(press, makeShot)
            }
        } catch {
            Self.logger.error("The shutter cannot fire", cause: error)
            return .failed(Self.serviceError(error))
        }
        return await handOver(fired)
    }

    /// Fires the shot with the camera that runs now, and returns once the camera has delivered its photo or failed
    /// to. The viewfinder blinks once the shot is on its way to the camera, which takes the next tap from then on, and
    /// the photo takes its turn after the photo fired before it. Throws when no shot can be made.
    private func shoot(_ press: Int, _ makeShot: () throws(CameraServiceError) -> PhotoShot) async throws -> FiredShot {
        let shot = try makeShot()
        captureCount += 1
        release(press)
        let turn = ShotTurn(after: lastTurn)
        lastTurn = turn
        let photo: Result<CapturedPhoto, any Error>
        do {
            photo = .success(try await service.capturePhoto(shot.request))
        } catch {
            photo = .failure(error)
        }
        return FiredShot(shot: shot, turn: turn, photo: photo)
    }

    /// Hands the photo of a fired shot over through its pipeline in its turn, once every photo fired before it is
    /// handed over or has failed. The pipeline runs for one photo at a time, and the turn of the next photo comes
    /// once this one is handed over or has failed.
    private func handOver(_ fired: FiredShot) async -> ShutterReport? {
        await fired.turn.begin()
        defer { fired.turn.end() }
        do {
            let photo = try fired.photo.get()
            let capture = try await fired.shot.pipeline.process(photo)
            delivery.handOver(capture)
            return (photo.losses + capture.losses).first.map(ShutterReport.handedOverWithout)
        } catch {
            Self.logger.error("Photo capture failed", cause: error)
            return .failed(Self.serviceError(error))
        }
    }

    private static func serviceError(_ error: any Error) -> CameraServiceError {
        guard let serviceError = error as? CameraServiceError else {
            return .captureFailed(String(describing: error))
        }
        return serviceError
    }
}

/// A shot the shutter fired: what it was taken with, its place in the order of the shutter, and the photo the camera
/// delivered or why it delivered none.
private struct FiredShot {
    let shot: PhotoShot
    let turn: ShotTurn
    let photo: Result<CapturedPhoto, any Error>
}
