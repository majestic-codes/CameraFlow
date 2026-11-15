//
//  PhotoCameraModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os

/// The camera screen as a set of models with one concern each, and what crosses between them: the life of the
/// camera, the second camera's circle beside it, the events it reports, the way the phone is held, the shutter, the
/// notices and a tap on the viewfinder.
///
/// It is the only model that knows the others. It hands each the values it needs from another, such as what a camera
/// that has started offers, hears what each reports, and runs every action that touches more than one of them.
@MainActor
final class PhotoCameraModel {
    let session: CameraSessionModel
    let notices: CameraNoticeModel
    let orientation: OrientationModel
    let captureControls: CaptureControlsModel
    let zoom: ZoomModel
    let settings: PhotoSettingsModel
    let panel: ControlPanelModel
    let focus: FocusModel
    let shutter: ShutterModel
    let delivery: CaptureDelivery
    let dualCamera: DualCameraModel
    /// The introduction that comes before the camera is asked for.
    let onboarding: OnboardingModel
    /// Saving to the photo library, which the settings and the set share, nil in a flow that never saves.
    let librarySaving: PhotoLibrarySavingModel?
    /// Where the photos take their location from, followed while the camera runs. Nil for photos without one.
    let location: (any PhotoLocationSource)?
    /// Where the photos take the direction of the camera from, followed while the camera runs. Nil for photos
    /// without one.
    let heading: (any PhotoHeadingSource)?
    /// One change of the camera runs at a time, never under a photo being taken. What the camera reports meanwhile
    /// is handled after it.
    let changes: CameraChangeGate
    /// Told when a press of the shutter has ended: its photo was handed over or failed, or it took none.
    var onCaptureEnded: (() -> Void)?

    private let service: any CameraService
    /// The zoom the screen opens with, nil for the main lens.
    private let initialZoomFactor: Double?
    /// The camera in the viewfinder when the screen opens with the circle on.
    private let openingDualCameraMain: CameraPosition
    private let haptics: any CameraHaptics
    private let attitudeSensor: any DeviceAttitudeSensor
    /// The restarts the camera has left after a recoverable error, without the user asking.
    private let automaticRestarts: AutomaticRestarts
    private static let logger = Logger.camera("PhotoCameraModel")

    init(
        service: any CameraService,
        haptics: any CameraHaptics,
        attitudeSensor: any DeviceAttitudeSensor,
        initialState: CameraFlowInitialState,
        quality: PhotoQualityModel,
        choices: UserChoices,
        librarySaving: PhotoLibrarySavingModel?,
        onboarding: OnboardingModel,
        clock: any Clock<Duration> = ContinuousClock(),
        files: CaptureFileStore,
        location: (any PhotoLocationSource)?,
        heading: (any PhotoHeadingSource)?,
        admission: (any CaptureAdmission)?,
        storage: any StorageSpace,
        backgroundWork: any BackgroundWork,
        onCapture: @escaping (CameraCapture) -> Void
    ) {
        self.service = service
        self.haptics = haptics
        self.attitudeSensor = attitudeSensor
        self.location = location
        self.heading = heading
        automaticRestarts = AutomaticRestarts(clock: clock)
        self.onboarding = onboarding
        self.librarySaving = librarySaving
        initialZoomFactor = initialState.zoomFactor
        openingDualCameraMain = initialState.isDualCameraSwapped ? .front : .back
        let pictureCovers = CameraPictureCovers()
        let dualCamera = DualCameraModel(
            setting: initialState.isDualCameraEnabled,
            isSupported: service.isDualCameraSupported,
            pictureCovers: pictureCovers
        )
        let settings = PhotoSettingsModel(
            initialState: initialState,
            quality: quality,
            choices: choices,
            librarySaving: librarySaving,
            isDualCameraOffered: dualCamera.isToggleOffered,
            service: service,
            haptics: haptics
        )
        let delivery = CaptureDelivery(files: files, receiver: onCapture)
        let changes = CameraChangeGate()
        session = CameraSessionModel(service: service, pictureCovers: pictureCovers)
        notices = CameraNoticeModel()
        orientation = OrientationModel()
        captureControls = CaptureControlsModel()
        self.settings = settings
        self.delivery = delivery
        self.dualCamera = dualCamera
        self.changes = changes
        zoom = ZoomModel(service: service, haptics: haptics)
        let tiles = settings.offeredSettings
        panel = ControlPanelModel(settings: tiles, presentation: initialState.panel, haptics: haptics)
        focus = FocusModel(service: service, clock: clock)
        shutter = ShutterModel(
            service: service,
            delivery: delivery,
            clock: clock,
            admission: admission,
            changes: changes,
            storage: storage,
            backgroundWork: backgroundWork
        )
        settings.onUserChange = { [weak self] in self?.clearNotices() }
        zoom.onLensChange = { [weak self] in self?.focus.unlock() }
    }

    // MARK: - Life of the camera

    /// Asks for the camera once the introduction has had its camera step, and starts it. A camera the flow stopped
    /// before it ever ran is not asked for again: it starts with the access it was granted. A saving to the photo
    /// library refused before the flow opened says so from now on. Without the introduction, the location is asked
    /// for once the camera runs.
    func start() async {
        await onboarding.waitForCameraStep()
        guard !Task.isCancelled else { return }
        let isGranted = await requestAccess()
        cameraActivityChanged()
        guard isGranted, !Task.isCancelled else { return }
        service.setEventHandler { [weak self] event in
            self?.handle(event)
        }
        attitudeSensor.start { [weak self] gravity in
            self?.gravityChanged(to: gravity)
        }
        followLocation()
        librarySaving?.applyStandingRefusal()
        await changes.run {
            await open()
        }
        guard !Task.isCancelled else { return }
        await onboarding.askForLocationWithoutIntroduction()
    }

    /// Asks for camera access and returns whether the camera may start. A camera the flow stopped before it ever ran
    /// had its access granted: it is active again, with a new row of automatic restarts, as a resumed camera is.
    private func requestAccess() async -> Bool {
        if session.capabilities == nil, session.cameraResumed() {
            automaticRestarts.reset()
            return true
        }
        return await session.requestAccess()
    }

    /// Follows the location and the direction for the photos, until the camera is stopped. The upright elements
    /// follow the phone from the first start until the camera closes, so a camera started again shows the quarter
    /// the phone is held in at once.
    private func followLocation() {
        location?.start()
        heading?.start()
    }

    /// Turns the upright elements with the phone, and the compass of the direction with them when the phone turns
    /// to another quarter.
    private func gravityChanged(to gravity: DeviceGravity) {
        let heldOrientation = orientation.heldOrientation
        orientation.gravityChanged(to: gravity)
        guard orientation.heldOrientation != heldOrientation else { return }
        heading?.deviceOrientationChanged(to: orientation.heldOrientation)
    }

    /// Starts the camera the screen opens with, at the zoom it opens with.
    private func open() async {
        if settings.opensWithDualCamera, dualCamera.isAvailable {
            await startDualCamera(main: openingDualCameraMain)
        } else {
            await startCamera(at: session.position)
        }
        if session.capabilities != nil, let initialZoomFactor {
            zoom.setZoom(initialZoomFactor)
        }
    }

    /// Stops the camera on purpose, with the self-timer and the location: it is not started again until it is
    /// resumed.
    func stop() {
        focus.clear()
        shutter.cancelCountdown()
        location?.stop()
        heading?.stop()
        automaticRestarts.cameraStopped()
        session.cameraStopped()
        cameraActivityChanged()
        service.stop()
    }

    /// Stops the camera as `stop()` does once the photos already fired are delivered, so that none is lost to the
    /// stop, and only if `isStillWanted` says so then: a change asked for meanwhile may have made the stop stale.
    func stopAfterFiredPhotos(if isStillWanted: () -> Bool) async {
        await changes.run {
            guard isStillWanted() else { return }
            stop()
        }
    }

    /// Starts a camera stopped on purpose again as it was: the same side and the same zoom, with the location
    /// followed again. The upright elements have followed the phone all along. The other settings live in the models
    /// and stay. A camera that never ran keeps its failure, which the user retries from.
    func resume() async {
        guard session.cameraResumed() else { return }
        cameraActivityChanged()
        automaticRestarts.reset()
        followLocation()
        guard session.capabilities != nil else { return }
        await changes.run {
            await restart()
        }
    }

    /// The user's way out of a failure: starts the camera again as it was, or as the screen opens when it never
    /// ran. Nothing happens while the camera runs, is not active or is being changed.
    func retry() async {
        guard session.isActive, let failure = session.failure, failure.isRetryable, !changes.isChanging else { return }
        automaticRestarts.reset()
        await changes.run {
            if session.capabilities == nil {
                await open()
            } else {
                await restart()
            }
        }
    }

    /// Starts the camera that ran again: the same side, alone or as a pair, and the same zoom. Returns whether it
    /// runs.
    @discardableResult
    private func restart() async -> Bool {
        let zoomFactor = zoom.factor
        let position = session.position
        let isRunning = session.isDualCameraOn
            ? await startDualCamera(main: position)
            : await startCamera(at: position)
        guard isRunning else { return false }
        zoom.setZoom(zoomFactor)
        return true
    }

    /// Stops the camera for good: captures still in flight are deleted when they finish, and the session's
    /// directory goes once nothing handed over is left in it. Nothing starts it again.
    func close() {
        stop()
        session.cameraClosed()
        cameraActivityChanged()
        attitudeSensor.stop()
        delivery.close()
    }

    /// Tells the circle whether the flow uses the camera, so its toggle is offered only then.
    private func cameraActivityChanged() {
        dualCamera.cameraActivityChanged(isActive: session.isActive)
    }

    /// Switches between the back and the front camera. With the circle on, the two swap places: the camera of the
    /// circle takes the viewfinder and the other goes into the circle. It waits for a photo that is being taken,
    /// which the camera delivers first. A tap while the camera is being changed, on a camera the flow does not use,
    /// and on a device with a camera on one side only is ignored.
    func flipCamera() async {
        guard session.isFlipOffered, session.isActive, !changes.isChanging else { return }
        await changes.run {
            guard session.isActive else { return }
            haptics.play(.cameraFlipped)
            focus.clear()
            zoom.closeDial()
            let flipped = session.position.flipped
            if session.isDualCameraOn {
                await startDualCamera(main: flipped)
            } else {
                await startCamera(at: flipped)
            }
        }
    }

    /// A finger came down on the flip button: the haptic of the flip its release starts is readied.
    func flipButtonTouched() {
        haptics.prepare(for: .cameraFlipped)
    }

    /// Starts the camera and puts every model on what has started, and returns whether it runs. A camera that
    /// cannot start changes nothing. It runs inside a change of the camera (`changes`), as the pair's start does.
    @discardableResult
    func startCamera(at position: CameraPosition) async -> Bool {
        zoom.cameraStarting()
        guard let capabilities = await session.startCamera(at: position) else { return false }
        return cameraStarted(capabilities)
    }

    /// Puts every model on the camera that has just started, and returns whether it runs: the zoom on its lenses,
    /// the circle and the settings on what runs and what it offers, and the focus on what it can lock. What the camera
    /// said before goes. A camera the flow stopped or closed while it was starting is stopped again, and the models
    /// wait for the next start.
    func cameraStarted(_ capabilities: CameraCapabilities) -> Bool {
        guard session.isActive else {
            service.stop()
            return false
        }
        zoom.cameraStarted(capabilities)
        dualCamera.cameraStarted(at: capabilities.position, isDualCameraOn: session.isDualCameraOn)
        settings.cameraStarted(photoCapabilities: session.photoCapabilities, isDualCameraOn: session.isDualCameraOn)
        focus.cameraStarted(lockableAdjustments: session.photoCapabilities?.lockableAdjustments)
        notices.clear()
        return true
    }
}

// MARK: - Events of the camera

extension PhotoCameraModel {

    private func handle(_ event: CameraSessionEvent) {
        switch event {
        case let .interrupted(reason):
            session.interrupted(by: reason)
            shutter.cancelCountdown()
        case .interruptionEnded:
            session.interruptionEnded()
        case let .runtimeError(error):
            sessionStopped(with: error)
        case let .captureControl(controlEvent):
            handle(controlEvent)
        case .dualCameraPressureCritical:
            Task {
                await dualCameraUnderPressure()
            }
        case .subjectAreaChanged:
            focus.subjectAreaChanged()
        case let .captureReadinessChanged(readiness):
            shutter.cameraReadinessChanged(to: readiness)
        case let .flashSceneChanged(isFlashScene):
            settings.flashSceneChanged(isFlashScene)
        case let .flashAvailabilityChanged(availability):
            settings.flashAvailabilityChanged(availability)
        }
    }

    /// The session stopped with an error. After one that a new start recovers from, such as a reset of the media
    /// services, the camera starts again as it was, like the stock camera does. Any other error, and one that keeps
    /// coming back, becomes the failure the user retries from. A camera the flow does not use stays as it is.
    private func sessionStopped(with error: CameraRuntimeError) {
        guard session.isActive else {
            Self.logger.info("A camera not in use reported an error: \(error.message, privacy: .public)")
            return
        }
        shutter.cancelCountdown()
        focus.clear()
        guard error.isRecoverable, automaticRestarts.take() else {
            Self.logger.error("The camera stopped with an error: \(error.message, privacy: .public)")
            session.stopped()
            return
        }
        Self.logger.notice("The camera stopped and is started again: \(error.message, privacy: .public)")
        Task {
            await restartAfterError()
        }
    }

    /// Starts the camera again, after a change that is under way, unless the flow stopped or closed it meanwhile.
    /// A camera that cannot start becomes the failure.
    private func restartAfterError() async {
        await changes.run {
            guard session.isActive else { return }
            if await restart() {
                automaticRestarts.cameraRestarted()
            }
        }
    }
}
