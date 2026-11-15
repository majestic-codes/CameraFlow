//
//  CaptureSessionCore+Events.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import os

// MARK: - What the sessions and the camera in the viewfinder report on their own

extension CaptureSessionCore {

    /// An observer that brings the notices of a session to the queue, for as long as the core lives.
    func makeObserver(of session: AVCaptureSession) -> CaptureSessionObserver {
        CaptureSessionObserver(session: session) { [weak self] notice in
            guard let self else { return }
            queue.async { self.handle(notice) }
        }
    }

    /// An observer that brings the changes of the picture of a camera in the viewfinder to the queue.
    func makeSubjectAreaObserver(of device: AVCaptureDevice) -> CaptureSubjectAreaObserver {
        let identifier = ObjectIdentifier(device)
        return CaptureSubjectAreaObserver(device: device) { [weak self] in
            guard let self else { return }
            queue.async { self.subjectAreaChanged(on: identifier) }
        }
    }

    /// An observation that brings the system pressure on the single camera to the queue, now and whenever it
    /// changes.
    func makePressureObservation(of device: AVCaptureDevice) -> NSKeyValueObservation {
        let identifier = ObjectIdentifier(device)
        return device.observe(\.systemPressureState, options: [.initial, .new]) { [weak self] device, _ in
            let pressure = CaptureDeviceInspector.pressure(of: device.systemPressureState)
            guard let self else { return }
            queue.async { self.singleCameraPressureChanged(to: pressure, on: identifier) }
        }
    }

    /// Throttles a camera of the pair under pressure, and gives the pair up once the pressure is critical.
    func dualCameraPressureChanged(to pressure: CaptureSystemPressure, at position: CameraPosition) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let dual else { return }
        CaptureDeviceControl.throttleFrameRate(of: dual.camera(at: position).device, under: pressure)
        if pressure == .critical {
            eventHandler?(.dualCameraPressureCritical)
        }
    }

    /// Throttles the single camera under pressure. Pressure that a camera reported before it stopped running alone
    /// is dropped.
    private func singleCameraPressureChanged(to pressure: CaptureSystemPressure, on identifier: ObjectIdentifier) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let device = input?.device, ObjectIdentifier(device) == identifier else { return }
        CaptureDeviceControl.throttleFrameRate(of: device, under: pressure)
    }

    private func handle(_ notice: CaptureSessionObserver.Notice) {
        dispatchPrecondition(condition: .onQueue(queue))
        switch notice {
        case let .interrupted(reason):
            eventHandler?(.interrupted(reason))
        case .interruptionEnded:
            eventHandler?(.interruptionEnded)
        case let .runtimeError(error):
            capturesInFlight.failAll()
            eventHandler?(.runtimeError(error))
        }
    }

    /// Reports a change of the picture of the camera in the viewfinder. A change that a camera reported before it
    /// left the viewfinder is dropped.
    private func subjectAreaChanged(on identifier: ObjectIdentifier) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let controlledDevice, ObjectIdentifier(controlledDevice) == identifier else { return }
        eventHandler?(.subjectAreaChanged)
    }
}
#endif
