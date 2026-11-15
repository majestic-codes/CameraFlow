//
//  PhotoCameraModel+Capture.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

// MARK: - The shutter

extension PhotoCameraModel {

    /// The shutter, as `ShutterModel.capture(timer:began:shot:)` runs it with the timer of the settings. What the
    /// camera said before goes once the tap starts a capture, and why the tap took no photo, or what the photo it
    /// handed over lacks, becomes the notice. `onCaptureEnded` hears the end of every press.
    func capture() async {
        let report = await shutter.capture(timer: settings.timer, began: clearNotices, shot: makeShot)
        switch report {
        case let .failed(error): notices.captureFailed(with: error)
        case let .handedOverWithout(loss): notices.showCaptureLossNotice(loss)
        case nil: break
        }
        onCaptureEnded?()
    }

    /// What the photo the shutter fires now is taken with: the settings as a request checked against the running
    /// camera, with the location for the photo, and the pipeline with the output of the quality chosen now, the place
    /// of the second camera's circle while it is on and the direction of the camera. Throws when no camera runs, when
    /// it is interrupted and when it cannot take the settings.
    private func makeShot() throws(CameraServiceError) -> PhotoShot {
        guard session.isActive, session.failure == nil, let photoCapabilities = session.photoCapabilities else {
            throw .notRunning
        }
        if let interruption = session.interruption {
            throw .interrupted(interruption)
        }
        let pipeline = PhotoCapturePipeline(
            aspectRatio: settings.aspectRatio,
            output: settings.output,
            store: delivery.files,
            dualCameraCircle: session.isDualCameraOn ? dualCamera.circle : nil,
            heading: heading?.heading,
            keepsLibraryPicture: settings.librarySaving != nil
        )
        var request = try settings.makeRequest(for: photoCapabilities)
        request.location = location?.location
        request.locatesLivePhotoMovie = settings.output.metadata == .kept
        return PhotoShot(request: request, pipeline: pipeline)
    }
}
