//
//  CapturePhotoOutputSetup.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation

/// The photo output of a camera set up for what the flow takes, the same for one camera alone and for each camera of
/// the pair.
enum CapturePhotoOutputSetup {

    /// Turns on what the camera's format offers for photos and the flow can use, so a capture can ask for it without a
    /// reconfiguration, and nothing more. The output takes photos up to the size the flow shoots at, and Live Photo
    /// and Apple ProRAW stay off in a flow that never takes them: each costs start time and memory. Its photos show
    /// the scene as the camera saw it, the front camera's too, as the stock camera saves them. Where the camera offers
    /// it, the output keeps up with quick shots as the stock camera does. Called while the session of the connected
    /// output is being configured.
    static func configure(_ output: AVCapturePhotoOutput, for device: AVCaptureDevice, features: PhotoCaptureFeatures) {
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        output.maxPhotoQualityPrioritization = .quality
        if let resolution = CaptureDeviceInspector.resolution(of: device) {
            output.maxPhotoDimensions = CMVideoDimensions(width: resolution.width, height: resolution.height)
        }
        output.isLivePhotoCaptureEnabled = features.livePhoto && output.isLivePhotoCaptureSupported
        output.isAppleProRAWEnabled = features.raw && output.isAppleProRAWSupported
        // Lens Correction, on by default in the stock camera: faces near the edges of a wide picture keep their shape.
        output.isContentAwareDistortionCorrectionEnabled = output.isContentAwareDistortionCorrectionSupported
        #if !targetEnvironment(macCatalyst)
        // A deferred photo comes back as a proxy that only Photos can finish. The flow hands over finished files.
        output.isAutoDeferredPhotoDeliveryEnabled = false
        #endif
        // Responsive capture starts the next photo while the one before is processed, and fast capture prioritization
        // lowers the quality of quick shots only. Both build on the zero shutter lag the system turns on by itself.
        output.isResponsiveCaptureEnabled = output.isResponsiveCaptureSupported
        output.isFastCapturePrioritizationEnabled = output.isFastCapturePrioritizationSupported
    }
}
#endif
