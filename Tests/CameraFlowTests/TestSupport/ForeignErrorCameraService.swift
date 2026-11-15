//
//  ForeignErrorCameraService.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
@testable import CameraFlow

/// An error that is none of the camera's own, as a framework under the camera throws.
struct ForeignCameraError: Error, CustomStringConvertible {
    let description: String
}

/// A camera whose starts and captures fail with an error that is not a `CameraServiceError`, where the test tells
/// it to. Everything else goes to the recording camera it wraps.
@MainActor
final class ForeignErrorCameraService: CameraService {
    let recording = RecordingCameraService()
    var startError: ForeignCameraError?
    var dualStartError: ForeignCameraError?
    var captureError: ForeignCameraError?

    var cameraPositions: [CameraPosition] {
        recording.cameraPositions
    }

    var isAuthorizationDetermined: Bool {
        recording.isAuthorizationDetermined
    }

    var isAuthorized: Bool {
        recording.isAuthorized
    }

    var isDualCameraSupported: Bool {
        recording.isDualCameraSupported
    }

    var photoCapabilities: PhotoCaptureCapabilities? {
        recording.photoCapabilities
    }

    func requestAuthorization() async -> CameraAuthorization {
        await recording.requestAuthorization()
    }

    func start(position: CameraPosition) async throws -> CameraCapabilities {
        if let startError {
            throw startError
        }
        return try await recording.start(position: position)
    }

    func startDualCamera(main: CameraPosition) async throws -> CameraCapabilities {
        if let dualStartError {
            throw dualStartError
        }
        return try await recording.startDualCamera(main: main)
    }

    func stop() {
        recording.stop()
    }

    func setZoom(_ factor: CGFloat) {
        recording.setZoom(factor)
    }

    func rampZoom(to factor: CGFloat, rate: Float) {
        recording.rampZoom(to: factor, rate: rate)
    }

    func focus(atDevicePoint point: CGPoint) {
        recording.focus(atDevicePoint: point)
    }

    func resetFocus() {
        recording.resetFocus()
    }

    func lockFocusAndExposure(atDevicePoint point: CGPoint) async -> Bool {
        await recording.lockFocusAndExposure(atDevicePoint: point)
    }

    func unlockFocusAndExposure() {
        recording.unlockFocusAndExposure()
    }

    func setEventHandler(_ handler: @escaping @MainActor (CameraSessionEvent) -> Void) {
        recording.setEventHandler(handler)
    }

    func setExposureBias(_ bias: Double) {
        recording.setExposureBias(bias)
    }

    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {
        recording.monitorFlashScene(for: flashMode, format: format)
    }

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto {
        if let captureError {
            throw captureError
        }
        return try await recording.capturePhoto(request)
    }

    func selectCaptureControlLens(at index: Int) {
        recording.selectCaptureControlLens(at: index)
    }

    func makePreview() -> any CameraPreview {
        recording.makePreview()
    }

    func makeCirclePreview() -> any CameraPreview {
        recording.makeCirclePreview()
    }
}
