//
//  ZoomPinchInteraction.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The pinch on the viewfinder that zooms the camera in it. It sets the zoom the way the dial does and shows the
/// dial meanwhile, which closes a while after the fingers have lifted, as after a turn of the dial.
@MainActor
final class ZoomPinchInteraction {
    private let zoom: ZoomModel
    private let dial: ZoomDialInteraction
    private var pinch: ZoomPinch?

    init(zoom: ZoomModel, dial: ZoomDialInteraction) {
        self.zoom = zoom
        self.dial = dial
    }

    /// Two fingers began to pinch. A pinch that begins while the camera does not zoom is ignored to its end.
    func began(isEnabled: Bool) {
        guard isEnabled else {
            pinch = nil
            return
        }
        pinch = ZoomPinch(startFactor: zoom.factor)
        dial.holdDialOpen()
    }

    /// The fingers are `magnification` times as far apart as when the pinch began.
    func changed(magnification: CGFloat) {
        guard let pinch, magnification.isFinite else { return }
        dial.holdDialOpen()
        zoom.setZoom(pinch.factor(atMagnification: magnification, on: zoom.scale))
    }

    /// The fingers lifted, or the system took the touch away. The zoom stays where the pinch left it.
    func ended() {
        guard pinch != nil else { return }
        pinch = nil
        dial.releaseDial()
    }
}
