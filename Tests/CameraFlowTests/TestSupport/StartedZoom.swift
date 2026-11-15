//
//  StartedZoom.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

/// The zoom of a camera started at a position, on its main lens: what the touches on the lens row, the dial and the
/// viewfinder turn. The test fails when the camera does not start.
@MainActor
func makeStartedZoom(
    service: RecordingCameraService,
    haptics: any CameraHaptics = RecordingCameraHaptics(),
    at position: CameraPosition = .back
) async throws -> ZoomModel {
    let session = CameraSessionModel(service: service, pictureCovers: CameraPictureCovers())
    let zoom = ZoomModel(service: service, haptics: haptics)
    let capabilities = try #require(await session.startCamera(at: position), "The camera did not start")
    zoom.cameraStarted(capabilities)
    return zoom
}
