//
//  CaptureSessionObserver.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// Turns the session's interruption and runtime error notifications into notices, for as long as it lives.
final class CaptureSessionObserver {
    enum Notice: Sendable {
        case interrupted(CameraInterruption)
        case interruptionEnded
        case runtimeError(CameraRuntimeError)
    }

    private let observers: [any NSObjectProtocol]

    init(session: AVCaptureSession, onNotice: @escaping @Sendable (Notice) -> Void) {
        let center = NotificationCenter.default
        let interrupted = center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: session,
            queue: nil
        ) { notification in
            let rawReason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            onNotice(.interrupted(CaptureDeviceInspector.interruption(rawReason: rawReason)))
        }
        let ended = center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: session,
            queue: nil
        ) { _ in
            onNotice(.interruptionEnded)
        }
        let runtimeError = center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: nil
        ) { notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? any Error
            onNotice(.runtimeError(CaptureDeviceInspector.runtimeError(error)))
        }
        observers = [interrupted, ended, runtimeError]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
#endif
