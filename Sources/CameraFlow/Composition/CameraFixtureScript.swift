//
//  CameraFixtureScript.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Plays the fixtures of a `CameraFlowInitialState` on a camera that has started: the open dial and the automatic
/// photos. A state without fixtures plays nothing.
@MainActor
struct CameraFixtureScript {
    let initialState: CameraFlowInitialState
    let clock: any Clock<Duration>

    /// How long the camera runs before the first automatic photo, so exposure and focus can settle.
    static let automaticCaptureDelay = Duration.seconds(1)

    init(initialState: CameraFlowInitialState, clock: any Clock<Duration> = ContinuousClock()) {
        self.initialState = initialState
        self.clock = clock
    }

    func play(on model: PhotoCameraModel) async {
        guard model.session.capabilities != nil else { return }
        if initialState.isZoomDialOpen {
            model.zoom.openDial()
        }
        let count = initialState.automaticCaptureCount
        if count > 0 {
            await takePhotos(count, with: model)
        }
    }

    /// Takes photos one after another, as if the shutter were tapped, until the task is cancelled.
    private func takePhotos(_ count: Int, with model: PhotoCameraModel) async {
        do {
            try await clock.sleep(for: Self.automaticCaptureDelay)
        } catch {
            return
        }
        for _ in 0..<count {
            guard !Task.isCancelled else { return }
            await model.capture()
        }
    }
}
