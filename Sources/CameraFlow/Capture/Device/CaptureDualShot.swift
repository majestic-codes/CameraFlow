//
//  CaptureDualShot.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// Waits for the two photos of one dual capture, the main camera's and the circle camera's, and hands them over as
/// one photo once both are in, the main photo alone when the circle's failed. `CaptureSessionCore` reports both
/// halves on its queue, which is what makes the unchecked sendability hold.
final class CaptureDualShot: @unchecked Sendable {
    private let queue: DispatchQueue
    private let viewfinderQuarterTurns: Int
    private let isViewfinderMirrored: Bool
    private let completion: @Sendable (Result<CapturedPhoto, any Error>) -> Void
    private var main: Result<CapturedPhoto, any Error>?
    private var circle: Result<CapturedPhoto, any Error>?

    /// - Parameter queue: The queue of `CaptureSessionCore`, which both halves are reported on.
    init(
        queue: DispatchQueue,
        viewfinderQuarterTurns: Int,
        isViewfinderMirrored: Bool,
        completion: @escaping @Sendable (Result<CapturedPhoto, any Error>) -> Void
    ) {
        self.queue = queue
        self.viewfinderQuarterTurns = viewfinderQuarterTurns
        self.isViewfinderMirrored = isViewfinderMirrored
        self.completion = completion
    }

    func mainFinished(_ result: Result<CapturedPhoto, any Error>) {
        dispatchPrecondition(condition: .onQueue(queue))
        main = result
        completeWhenBothAreIn()
    }

    func circleFinished(_ result: Result<CapturedPhoto, any Error>) {
        dispatchPrecondition(condition: .onQueue(queue))
        circle = result
        completeWhenBothAreIn()
    }

    /// The settings of the circle's frame: a still without flash at the smallest size of the camera's format that
    /// covers the circle, at a balanced quality, which the small frame does not need more of. Its file is HEIF where
    /// the output encodes HEVC.
    static func circleSettings(
        for output: AVCapturePhotoOutput,
        of device: AVCaptureDevice
    ) -> CapturePhotoSettingsBuilder.Built {
        let built = CapturePhotoSettingsBuilder.processedSettings(for: output)
        let format = device.activeFormat
        built.settings.maxPhotoDimensions = CaptureDualFormats.circlePhotoDimensions(
            of: format,
            within: output.maxPhotoDimensions
        )
        built.settings.photoQualityPrioritization = .balanced
        return built
    }

    private func completeWhenBothAreIn() {
        guard let main, let circle else { return }
        let photo = DualCapturePhoto.combining(
            main: main,
            circle: circle,
            isViewfinderMirrored: isViewfinderMirrored,
            viewfinderQuarterTurns: viewfinderQuarterTurns
        )
        completion(photo)
    }
}
#endif
