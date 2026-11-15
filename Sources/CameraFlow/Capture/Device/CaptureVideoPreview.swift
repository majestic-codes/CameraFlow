//
//  CaptureVideoPreview.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import AVFoundation
import QuartzCore

/// The live picture of a camera, filling its layer: the camera of the viewfinder, or the camera in the circle of a
/// dual camera.
///
/// The viewfinder has a video layer of its own, attached to the session of one camera with its own connection. The
/// multi-camera session has one layer for each camera of the pair, which the camera service lends to the preview of
/// the place that camera shows in. A layer never moves between the sessions or the cameras; the preview shows the
/// one of the session that runs.
@MainActor
final class CaptureVideoPreview: CameraPreview {
    private let container = PreviewContainerLayer()
    private let singleLayer: AVCaptureVideoPreviewLayer?
    /// The layer of the camera of the pair this preview shows now, nil until one was lent.
    private var dualLayer: AVCaptureVideoPreviewLayer?
    private var showsDualCamera = false

    /// The viewfinder's preview, which shows the single camera until a layer of the pair is lent to it.
    init(core: CaptureSessionCore) {
        let singleLayer = AVCaptureVideoPreviewLayer(session: core.session)
        singleLayer.videoGravity = .resizeAspectFill
        container.addSublayer(singleLayer)
        self.singleLayer = singleLayer
        core.addSinglePreviewLayer(singleLayer)
    }

    /// The circle's preview, which shows nothing until a layer of the pair is lent to it.
    init() {
        singleLayer = nil
    }

    var layer: CALayer {
        container
    }

    /// Shows the single camera again, where the preview has it.
    func showSingleCamera() {
        showsDualCamera = false
        applyVisibility()
    }

    /// Shows a camera of the pair in its layer, taking the layer from the preview that showed it before. The
    /// layer keeps its connection, so its picture goes on without a break.
    func showDualCamera(in layer: AVCaptureVideoPreviewLayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let dualLayer, dualLayer !== layer, dualLayer.superlayer === container {
            dualLayer.removeFromSuperlayer()
        }
        if layer.superlayer !== container {
            container.addSublayer(layer)
        }
        layer.frame = container.bounds
        CATransaction.commit()
        dualLayer = layer
        showsDualCamera = true
        applyVisibility()
    }

    private func applyVisibility() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        singleLayer?.isHidden = showsDualCamera
        if let dualLayer, dualLayer.superlayer === container {
            dualLayer.isHidden = !showsDualCamera
        }
        CATransaction.commit()
    }

    /// Nil for the circle's preview before a layer of the pair was lent to it.
    func devicePoint(atLayerPoint point: CGPoint) -> CGPoint? {
        let shown = showsDualCamera ? dualLayer : singleLayer
        return shown?.captureDevicePointConverted(fromLayerPoint: point)
    }
}

/// The two layers of the multi-camera session, one for each camera of the pair, each connected to its camera for
/// as long as the pair runs. The cameras swap places on screen by these layers changing places.
@MainActor
struct DualPreviewLayers {
    private let back: AVCaptureVideoPreviewLayer
    private let front: AVCaptureVideoPreviewLayer

    /// Nil on a device that cannot run two cameras.
    init?(core: CaptureSessionCore) {
        guard let session = core.multiCamSession else { return nil }
        back = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        front = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        for (layer, position) in [(back, CameraPosition.back), (front, CameraPosition.front)] {
            layer.videoGravity = .resizeAspectFill
            core.addDualPreviewLayer(layer, showing: position)
        }
    }

    func layer(showing position: CameraPosition) -> AVCaptureVideoPreviewLayer {
        position == .back ? back : front
    }
}

/// A layer whose sublayers always fill it, without an animation.
private final class PreviewContainerLayer: CALayer {

    override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sublayers?.forEach { $0.frame = bounds }
        CATransaction.commit()
    }
}
#endif
