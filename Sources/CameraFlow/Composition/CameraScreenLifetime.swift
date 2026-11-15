//
//  CameraScreenLifetime.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The life of one camera screen, tied to the task of the view that shows it.
@MainActor
enum CameraScreenLifetime {

    /// Runs the camera for as long as the calling task lives, and closes it when the task is cancelled. The script
    /// plays once the camera has started.
    static func run(_ model: PhotoCameraModel, script: CameraFixtureScript) async {
        await model.start()
        await script.play(on: model)
        await waitUntilCancelled()
        model.close()
    }

    /// Runs a flow for as long as the calling task lives. When the task is cancelled the flow ends as `end(_:)` says.
    static func run<Canvas: MarkupCanvas>(_ flow: CameraFlowModel<Canvas>, script: CameraFixtureScript) async {
        await flow.camera.start()
        await script.play(on: flow.camera)
        await waitUntilCancelled()
        end(flow)
    }

    /// Brings the camera of a flow back when its screen is on view again: a camera that never ran starts, as it does
    /// when its view first appears, and one that ran starts again as it was. A flow in the review keeps its camera
    /// stopped, as the review does, and so does a set that is being handed over or has ended.
    static func resume<Canvas: MarkupCanvas>(_ flow: CameraFlowModel<Canvas>) async {
        guard flow.mode == .shooting, !flow.isHandingOver, !flow.photoSet.hasEnded else { return }
        if flow.camera.session.capabilities == nil {
            await flow.camera.start()
        } else {
            await flow.camera.resume()
        }
    }

    /// Ends a flow: the camera is closed and the set discarded, unless it was handed over. A set that is being handed
    /// over just then is handed over all the same: its hand-over does not belong to the screen.
    static func end<Canvas: MarkupCanvas>(_ flow: CameraFlowModel<Canvas>) {
        flow.camera.close()
        flow.photoSet.discard()
    }

    /// Returns when the calling task is cancelled.
    static func waitUntilCancelled() async {
        // The stream never yields, and its iteration ends when the task is cancelled.
        let (stream, continuation) = AsyncStream<Never>.makeStream()
        for await _ in stream {}
        continuation.finish()
    }
}
