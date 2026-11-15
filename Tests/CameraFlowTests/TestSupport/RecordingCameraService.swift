//
//  RecordingCameraService.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The simulated camera with a record of every call, and switches that make it fail.
///
/// Like the device's, it takes a photo only while a session runs: from a start that returned until the camera stops
/// or its session reports a runtime error. A capture it holds ends as not running when the camera is stopped or
/// started again meanwhile, as the protocol asks. Its events reach the handler as the device's do: through a stream
/// the main actor drains on a later turn, after the work already queued, and a runtime error fails the captures in
/// flight before the handler hears of it.
@MainActor
final class RecordingCameraService: CameraService {
    /// An event the camera reported, with what `simulate(_:)` waits on until the handler has taken it.
    private struct DeliveryWaiter {
        let eventNumber: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    let simulated: SimulatedCameraService
    private(set) var calls: [Call] = []
    /// Indexes passed to `selectCaptureControlLens(at:)`, in order, kept apart from `calls`.
    private(set) var captureControlLensIndexes: [Int] = []
    /// What `monitorFlashScene(for:format:)` was asked to monitor, in order, kept apart from `calls`.
    private(set) var monitoredFlashScenes: [MonitoredFlashScene] = []
    var authorization = CameraAuthorization.authorized
    var cameraPositions: [CameraPosition] = [.back, .front]
    /// False for a camera the user has not been asked for yet. Asking gives it its answer.
    var isAuthorizationDetermined = true

    var isAuthorized: Bool {
        isAuthorizationDetermined && authorization == .authorized
    }

    /// Holds `requestAuthorization()` until `releaseHeldCalls()`, as the system's request waits for the user.
    var holdsAuthorization = false
    /// How many times access was asked for.
    private(set) var authorizationRequestCount = 0
    var startError: CameraServiceError?
    /// Thrown by `startDualCamera(main:)` in place of starting the pair.
    var dualStartError: CameraServiceError?
    var captureError: CameraServiceError?
    /// Delivered by `capturePhoto(_:)` in place of the simulated photo.
    var deliveredPhoto: CapturedPhoto?
    /// Holds `start(position:)`, `startDualCamera(main:)` and `capturePhoto(_:)` after recording them, until
    /// `releaseHeldCalls()`.
    var holdsCalls = false
    private var heldCalls: [CheckedContinuation<Void, Never>] = []
    private var heldCaptures: [CheckedContinuation<Void, Never>] = []
    /// How many captures have ended, with a photo or with an error.
    private(set) var endedCaptureCount = 0
    /// Holds `lockFocusAndExposure(atDevicePoint:)` after recording it, as the device does while it settles, until
    /// `settleFocusLock()` or a call that gives the lock up.
    var holdsFocusLock = false
    private var heldFocusLock: CheckedContinuation<Bool, Never>?
    /// Goes up whenever the camera is stopped or started, which ends the captures in flight.
    private var sessionNumber = 0
    /// Whether a session runs, which a capture needs.
    private(set) var isRunning = false
    private var eventHandler: (@MainActor (CameraSessionEvent) -> Void)?
    /// The events on their way to the handler.
    private let events = AsyncStream<CameraSessionEvent>.makeStream()
    private var eventDelivery: Task<Void, Never>?
    private var postedEventCount = 0
    private var deliveredEventCount = 0
    private var deliveryWaiters: [DeliveryWaiter] = []

    init(
        backPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneBackPhotoCapabilities,
        frontPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneFrontPhotoCapabilities,
        dualPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneDualPhotoCapabilities,
        isDualCameraSupported: Bool = true
    ) {
        simulated = SimulatedCameraService(
            scene: .black,
            backPhotoCapabilities: backPhotoCapabilities,
            frontPhotoCapabilities: frontPhotoCapabilities,
            dualPhotoCapabilities: dualPhotoCapabilities,
            isDualCameraSupported: isDualCameraSupported
        )
        eventDelivery = Task { [weak self, stream = events.stream] in
            for await event in stream {
                self?.deliver(event)
            }
        }
    }

    deinit {
        eventDelivery?.cancel()
    }

    /// A camera the user has not been asked for yet, which a request gives `answer`.
    static func unasked(answering answer: CameraAuthorization = .authorized) -> RecordingCameraService {
        let service = RecordingCameraService()
        service.isAuthorizationDetermined = false
        service.authorization = answer
        return service
    }

    var isDualCameraSupported: Bool {
        simulated.isDualCameraSupported
    }

    func startDualCamera(main: CameraPosition) async throws -> CameraCapabilities {
        calls.append(.startDualCamera(main: main))
        endSession()
        await holdIfAsked()
        do {
            if let dualStartError {
                throw dualStartError
            }
            let capabilities = try await simulated.startDualCamera(main: main)
            isRunning = true
            return capabilities
        } catch {
            isRunning = false
            throw error
        }
    }

    func makeCirclePreview() -> any CameraPreview {
        simulated.makeCirclePreview()
    }

    var photoCapabilities: PhotoCaptureCapabilities? {
        simulated.photoCapabilities
    }

    func requestAuthorization() async -> CameraAuthorization {
        authorizationRequestCount += 1
        if holdsAuthorization {
            await withCheckedContinuation { heldCalls.append($0) }
        }
        isAuthorizationDetermined = true
        return authorization
    }

    var heldCallCount: Int {
        heldCalls.count + heldCaptures.count
    }

    func releaseHeldCalls() {
        let released = heldCalls + heldCaptures
        heldCalls = []
        heldCaptures = []
        released.forEach { $0.resume() }
    }

    /// Lets one held capture go on alone: the one at `index` among the captures held now, in the order they were
    /// asked for.
    func releaseHeldCapture(at index: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        guard heldCaptures.indices.contains(index) else {
            let problem = "No capture is held at \(index): \(heldCaptures.count) are held"
            Issue.record(Comment(rawValue: problem), sourceLocation: sourceLocation)
            return
        }
        heldCaptures.remove(at: index).resume()
    }

    /// Ends the session that ran: the captures it holds go on at once, to find their session gone, and a lock that
    /// still settles is given up.
    private func endSession() {
        sessionNumber += 1
        endFocusLock(isLocked: false)
        let released = heldCaptures
        heldCaptures = []
        released.forEach { $0.resume() }
    }

    func start(position: CameraPosition) async throws -> CameraCapabilities {
        calls.append(.start(position))
        endSession()
        await holdIfAsked()
        do {
            if let startError {
                throw startError
            }
            let capabilities = try await simulated.start(position: position)
            isRunning = true
            return capabilities
        } catch {
            isRunning = false
            throw error
        }
    }

    func stop() {
        calls.append(.stop)
        endSession()
        isRunning = false
        simulated.stop()
    }

    func setEventHandler(_ handler: @escaping @MainActor (CameraSessionEvent) -> Void) {
        eventHandler = handler
    }

    /// Reports an event as the session does: an interruption, a Camera Control change, a runtime error. The handler
    /// takes it on a later turn of the main actor, after the work already queued, so whatever the test does before
    /// it yields comes first. A runtime error ends the session first: the captures in flight fail before the handler
    /// hears of it.
    func post(_ event: CameraSessionEvent) {
        if case .runtimeError = event {
            endSession()
            isRunning = false
        }
        postedEventCount += 1
        events.continuation.yield(event)
    }

    /// Reports an event as `post(_:)` does and returns once the handler has taken it, as `waitForPostedEvents()`.
    func simulate(_ event: CameraSessionEvent) async {
        post(event)
        await waitForPostedEvents()
    }

    /// Returns once the handler has taken every event posted so far. The tasks the handler started run on turns
    /// of their own, which this does not wait for.
    func waitForPostedEvents() async {
        let eventNumber = postedEventCount
        guard deliveredEventCount < eventNumber else { return }
        await withCheckedContinuation { continuation in
            deliveryWaiters.append(DeliveryWaiter(eventNumber: eventNumber, continuation: continuation))
        }
    }

    /// Hands an event to the handler and lets the waits for it go on. An event that comes before the handler is set
    /// goes nowhere, as the session's does.
    private func deliver(_ event: CameraSessionEvent) {
        eventHandler?(event)
        deliveredEventCount += 1
        let delivered = deliveryWaiters.filter { $0.eventNumber <= deliveredEventCount }
        deliveryWaiters.removeAll { $0.eventNumber <= deliveredEventCount }
        delivered.forEach { $0.continuation.resume() }
    }

    func setZoom(_ factor: CGFloat) {
        calls.append(.setZoom(factor))
    }

    func rampZoom(to factor: CGFloat, rate: Float) {
        calls.append(.rampZoom(factor))
    }

    func focus(atDevicePoint point: CGPoint) {
        calls.append(.focus(point))
        endFocusLock(isLocked: false)
    }

    func resetFocus() {
        calls.append(.resetFocus)
        endFocusLock(isLocked: false)
    }

    func setExposureBias(_ bias: Double) {
        calls.append(.exposureBias(bias))
        simulated.setExposureBias(bias)
    }

    /// Records the mode and the format. The scene and the flash are what the test reports with `simulate(_:)`.
    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {
        monitoredFlashScenes.append(MonitoredFlashScene(flashMode: flashMode, format: format))
    }

    /// Takes a photo while a session runs, at the call and when the test lets a held capture go on, and fails as
    /// not running otherwise.
    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto {
        calls.append(.capture(request))
        defer { endedCaptureCount += 1 }
        guard isRunning else {
            throw CameraServiceError.notRunning
        }
        let session = sessionNumber
        if holdsCalls {
            await withCheckedContinuation { heldCaptures.append($0) }
        }
        guard session == sessionNumber, isRunning else {
            throw CameraServiceError.notRunning
        }
        if let captureError {
            throw captureError
        }
        if let deliveredPhoto {
            return deliveredPhoto
        }
        // A Live Photo movie goes under the directory of the test, which removes it.
        simulated.temporaryDirectory = TestDirectory.current
        return try await simulated.capturePhoto(request)
    }

    func selectCaptureControlLens(at index: Int) {
        captureControlLensIndexes.append(index)
    }

    func makePreview() -> any CameraPreview {
        simulated.makePreview()
    }

    private func holdIfAsked() async {
        guard holdsCalls else { return }
        await withCheckedContinuation { continuation in
            heldCalls.append(continuation)
        }
    }
}

// MARK: - The lock of the focus and the exposure

extension RecordingCameraService {

    /// Locks at once while a session runs, or once the test settles a held lock. As on the device, a new lock, a
    /// focus, a reset, an unlock, a start and a stop give up a lock that still settles, and a camera that does not
    /// run does not lock.
    func lockFocusAndExposure(atDevicePoint point: CGPoint) async -> Bool {
        calls.append(.lockFocusAndExposure(point))
        endFocusLock(isLocked: false)
        guard isRunning else { return false }
        guard holdsFocusLock else { return true }
        return await withCheckedContinuation { continuation in
            heldFocusLock = continuation
        }
    }

    func unlockFocusAndExposure() {
        calls.append(.unlockFocusAndExposure)
        endFocusLock(isLocked: false)
    }

    /// Whether a lock waits for the camera to settle.
    var isFocusLockHeld: Bool {
        heldFocusLock != nil
    }

    /// Lets the held lock end as the camera settled into it.
    func settleFocusLock() {
        endFocusLock(isLocked: true)
    }

    /// Ends the held lock with an answer. Without one, nothing happens.
    private func endFocusLock(isLocked: Bool) {
        let held = heldFocusLock
        heldFocusLock = nil
        held?.resume(returning: isLocked)
    }
}

extension CameraRuntimeError {
    /// A reset of the media services, which a new start of the camera recovers from.
    static let mediaServicesReset = CameraRuntimeError(message: "Media services were reset", isRecoverable: true)
    /// A fault of the camera, which no new start recovers from.
    static let hardwareFault = CameraRuntimeError(message: "The camera failed", isRecoverable: false)
}
