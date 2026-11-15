//
//  SinglePreviewLevels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// The layers of the viewfinder that show the single camera, each kept level with the horizon of the interface it
/// is shown in by a rotation coordinator of the running camera: portrait on a phone, any quarter on an iPad. Read and
/// written on the queue of `CaptureSessionCore` only.
final class SinglePreviewLevels {
    private let queue: DispatchQueue
    private var layers: [SinglePreviewLayerReference] = []
    private var levels: [PreviewLevel] = []

    /// - Parameter queue: The queue of `CaptureSessionCore`.
    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func add(_ layer: SinglePreviewLayerReference) {
        dispatchPrecondition(condition: .onQueue(queue))
        layers.append(layer)
    }

    /// Turns every layer level with its interface for the camera that runs, now and whenever the interface turns.
    /// Without a camera nothing is kept level.
    func level(with device: AVCaptureDevice?) {
        dispatchPrecondition(condition: .onQueue(queue))
        layers.removeAll { $0.layer == nil }
        guard let device else {
            levels = []
            return
        }
        levels = layers.compactMap { reference in
            guard let layer = reference.layer, let connection = layer.connection else { return nil }
            return PreviewLevel(connection, of: layer, device: device, queue: queue)
        }
    }
}
#endif
