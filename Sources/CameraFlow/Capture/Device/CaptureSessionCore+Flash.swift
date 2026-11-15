//
//  CaptureSessionCore+Flash.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

// MARK: - The flash of the camera in the viewfinder

extension CaptureSessionCore {

    /// Monitors the scene of the camera in the viewfinder for the flash in this mode, as the next photo in the format
    /// would be taken, and the scene of every camera that comes into the viewfinder later.
    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {
        queue.async {
            self.flashWatch.monitor(flashMode, format: format)
        }
    }

    /// Follows the flash of the camera that came into the viewfinder: its scene in the monitored mode and whether it
    /// can fire, reported now and whenever they change. Called on the queue.
    func watchFlash(of device: AVCaptureDevice, output: AVCapturePhotoOutput) {
        dispatchPrecondition(condition: .onQueue(queue))
        flashWatch.watch(device, output: output) { [weak self] in
            guard let self else { return }
            queue.async { self.reportFlashChanges() }
        }
    }

    /// Reports what changed in the flash of the camera in the viewfinder since it was reported last.
    private func reportFlashChanges() {
        dispatchPrecondition(condition: .onQueue(queue))
        for event in flashWatch.changes() {
            eventHandler?(event)
        }
    }
}
#endif
