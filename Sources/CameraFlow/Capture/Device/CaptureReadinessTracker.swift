//
//  CaptureReadinessTracker.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// The readiness to take another photo of the photo outputs that take photos now: the single camera's, or the two of
/// the pair, which take one photo together. Each output is followed through a readiness coordinator of its own, and
/// the readiness of them all is reported whenever it changes. Everything is read and written on the queue of
/// `CaptureSessionCore`, where the reports of the coordinators cross to, which is what makes the unchecked
/// sendability hold.
final class CaptureReadinessTracker: @unchecked Sendable {
    private let queue: DispatchQueue
    private let report: (CaptureReadiness) -> Void
    /// The outputs that take photos now, each with what follows its readiness.
    private var followed: [CapturePhotoReadiness] = []
    /// The readiness reported last, nil before the first report and after `reportAgain()`.
    private var reported: CaptureReadiness?

    /// - Parameter report: Takes the readiness on the queue whenever it changes.
    init(queue: DispatchQueue, report: @escaping (CaptureReadiness) -> Void) {
        self.queue = queue
        self.report = report
    }

    /// Follows the outputs that take photos from now on, none while no camera is set up, and reports their readiness
    /// when it changed. An output followed before goes on with what follows it.
    func follow(_ outputs: [AVCapturePhotoOutput]) {
        dispatchPrecondition(condition: .onQueue(queue))
        followed = outputs.map { output in
            followed.first { $0.output === output } ?? makeReadiness(of: output)
        }
        reportChange()
    }

    /// Counts a request in the readiness of its output until the output takes it in.
    func track(_ settings: AVCapturePhotoSettings, on output: AVCapturePhotoOutput) {
        dispatchPrecondition(condition: .onQueue(queue))
        followed.first { $0.output === output }?.track(settings)
    }

    /// Reports the readiness as it is now, whether it changed or not, for a receiver that has not heard it yet.
    func reportAgain() {
        dispatchPrecondition(condition: .onQueue(queue))
        reported = nil
        reportChange()
    }

    private func makeReadiness(of output: AVCapturePhotoOutput) -> CapturePhotoReadiness {
        CapturePhotoReadiness(output: output) { [weak self] outputReadiness, readiness in
            guard let self else { return }
            queue.async { self.outputReadiness(outputReadiness, changedTo: readiness) }
        }
    }

    /// Takes in what one output reported. The report of an output that takes no photos any more is dropped.
    private func outputReadiness(_ outputReadiness: CapturePhotoReadiness, changedTo readiness: CaptureReadiness) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard followed.contains(where: { $0 === outputReadiness }) else { return }
        outputReadiness.latest = readiness
        reportChange()
    }

    /// Reports the readiness of the outputs that take photos now, when it is another than the one reported last.
    private func reportChange() {
        let readiness = combinedReadiness
        guard readiness != reported else { return }
        reported = readiness
        report(readiness)
    }

    /// The readiness of the outputs that take photos now: ready only when every one is. An output that has not
    /// reported yet does not run, and neither does a camera without an output.
    private var combinedReadiness: CaptureReadiness {
        let readinesses = followed.map { $0.latest ?? .notRunning }
        guard let first = readinesses.first else { return .notRunning }
        return readinesses.dropFirst().reduce(first) { $0.combined(with: $1) }
    }
}
#endif
