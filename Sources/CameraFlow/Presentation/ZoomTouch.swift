//
//  ZoomTouch.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The touches on the zoom of one camera screen: the lens row with its dial, and the pinch on the viewfinder, which
/// shows the dial while it zooms. Made once for a flow and kept as long as it runs.
@MainActor
struct ZoomTouch {
    let dial: ZoomDialInteraction
    let pinch: ZoomPinchInteraction

    init(zoom: ZoomModel) {
        let dial = ZoomDialInteraction(zoom: zoom)
        self.dial = dial
        pinch = ZoomPinchInteraction(zoom: zoom, dial: dial)
    }
}
