//
//  FlowScreenModels.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the screen of one flow runs on: the flow and the touches on its zoom, made together once and kept together
/// for as long as the flow runs.
@MainActor
struct FlowScreenModels<Canvas: MarkupCanvas> {
    let flow: CameraFlowModel<Canvas>
    let zoomTouch: ZoomTouch

    init(flow: CameraFlowModel<Canvas>) {
        self.flow = flow
        zoomTouch = ZoomTouch(zoom: flow.camera.zoom)
    }
}
