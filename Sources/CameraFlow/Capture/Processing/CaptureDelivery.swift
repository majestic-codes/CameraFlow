//
//  CaptureDelivery.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Hands finished captures to the receiver while the screen is open, and deletes them once it has closed: the
/// receiver owns what it got, the camera cleans up the rest.
@MainActor
final class CaptureDelivery {
    let files: CaptureFileStore
    private let receiver: (CameraCapture) -> Void
    private(set) var isClosed = false

    init(files: CaptureFileStore, receiver: @escaping (CameraCapture) -> Void) {
        self.files = files
        self.receiver = receiver
    }

    /// Gives the capture to the receiver, or deletes its files once closed. The directory goes as soon as it is
    /// empty: a receiver that moves the files at once leaves nothing behind, even when the app is killed with
    /// the camera open.
    func handOver(_ capture: CameraCapture) {
        defer { files.removeDirectoryIfEmpty() }
        guard !isClosed else {
            CaptureFileStore.discardFiles(of: capture)
            return
        }
        receiver(capture)
    }

    /// Captures that finish from now on are deleted. The directory goes once nothing handed over is left in it.
    func close() {
        isClosed = true
        files.removeDirectoryIfEmpty()
    }
}
