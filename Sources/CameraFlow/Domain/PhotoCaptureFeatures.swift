//
//  PhotoCaptureFeatures.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The costly photo features a flow can ever ask its camera for. A camera turns on only these: each one it keeps
/// ready makes the session slower to start and heavier in memory, and a camera without one reports that it has none.
struct PhotoCaptureFeatures: Sendable, Equatable {
    /// Live Photo: the flow offers it to the user or fixes it on.
    let livePhoto: Bool
    /// Apple ProRAW: the flow offers the format or fixes it, and its output takes a DNG as it is.
    let raw: Bool

    /// Every feature, for a camera that serves any flow.
    static let all = Self(livePhoto: true, raw: true)

    init(livePhoto: Bool, raw: Bool) {
        self.livePhoto = livePhoto
        self.raw = raw
    }

    /// What a flow with these camera settings and this output can use.
    init(camera: CameraFlowInitialState, output: CameraFlowOutput) {
        let format = camera.photoFormat
        self.init(
            livePhoto: camera.isLivePhotoEnabled.canBeOn,
            raw: output.leavesFilesAsTheyAre && (format.isUserAdjustable || format.value == .raw)
        )
    }
}
