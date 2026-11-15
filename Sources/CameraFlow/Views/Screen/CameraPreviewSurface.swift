//
//  CameraPreviewSurface.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Hosts a camera preview and reports taps, long presses, drags and pinches on it.
struct CameraPreviewSurface: UIViewRepresentable {
    /// Makes the preview the surface shows for as long as it lives.
    let makePreview: () -> any CameraPreview
    /// The covers the surface's picture joins.
    let covers: CameraPictureCovers
    /// Receives a tap as a point of the surface, and as the point of the camera's coordinates it shows.
    let onTap: (CGPoint, CGPoint) -> Void
    /// Receives where a long press began, in the same two coordinates as a tap.
    let onLongPressBegan: (CGPoint, CGPoint) -> Void
    /// Receives that the finger of a long press let go, or that the press was cancelled.
    let onLongPressEnded: () -> Void
    /// Receives where a vertical drag began, in the same two coordinates as a tap.
    let onDragBegan: (CGPoint, CGPoint) -> Void
    /// Receives how many points below its start a drag is.
    let onDragMoved: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onPinchBegan: () -> Void
    /// Receives how many times as far apart the fingers are as when the pinch began.
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: () -> Void

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView(preview: makePreview())
        covers.add(view)
        configure(view)
        return view
    }

    func updateUIView(_ view: PreviewHostView, context: Context) {
        configure(view)
    }

    private func configure(_ view: PreviewHostView) {
        view.onTap = onTap
        view.onLongPressBegan = onLongPressBegan
        view.onLongPressEnded = onLongPressEnded
        view.onDragBegan = onDragBegan
        view.onDragMoved = onDragMoved
        view.onDragEnded = onDragEnded
        view.onPinchBegan = onPinchBegan
        view.onPinchChanged = onPinchChanged
        view.onPinchEnded = onPinchEnded
    }
}

final class PreviewHostView: PreviewLayerView {
    var onTap: (CGPoint, CGPoint) -> Void = { _, _ in }
    var onLongPressBegan: (CGPoint, CGPoint) -> Void = { _, _ in }
    var onLongPressEnded: () -> Void = {}
    var onDragBegan: (CGPoint, CGPoint) -> Void = { _, _ in }
    var onDragMoved: (CGFloat) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    var onPinchBegan: () -> Void = {}
    var onPinchChanged: (CGFloat) -> Void = { _ in }
    var onPinchEnded: () -> Void = {}

    override init(preview: any CameraPreview) {
        super.init(preview: preview)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        // A finger that holds still is the stock AE/AF Lock's long press, so a tap waits until it lets go sooner.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        longPress.minimumPressDuration = CameraMotion.FocusLock.pressDuration
        tap.require(toFail: longPress)
        addGestureRecognizer(tap)
        addGestureRecognizer(longPress)
        // A drag is one finger's, so two fingers on the viewfinder are a pinch and never a drag. The recognizers
        // exclude each other: a pinch that began takes the touch from the tap and the drag.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A pan reports every drag. Only its vertical travel matters, and a pan can begin with no travel at all, so
    /// nothing about its direction is decided when it begins.
    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let translation = recognizer.translation(in: self)
            let location = recognizer.location(in: self)
            let point = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
            recognizer.setTranslation(.zero, in: self)
            guard let devicePoint = preview.devicePoint(atLayerPoint: point) else { return }
            onDragBegan(point, devicePoint)
        case .changed:
            onDragMoved(recognizer.translation(in: self).y)
        case .ended, .cancelled:
            onDragEnded()
        default:
            break
        }
    }

    @objc private func pinched(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            onPinchBegan()
            onPinchChanged(recognizer.scale)
        case .changed:
            onPinchChanged(recognizer.scale)
        case .ended, .cancelled:
            onPinchEnded()
        default:
            break
        }
    }

    /// A long press reports where it began and when it ends, and its moves in between do not matter to the lock. A
    /// press on a preview that shows no camera has nothing to lock on, so it reports only its end.
    @objc private func longPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point = recognizer.location(in: self)
            guard let devicePoint = preview.devicePoint(atLayerPoint: point) else { return }
            onLongPressBegan(point, devicePoint)
        case .ended, .cancelled, .failed:
            onLongPressEnded()
        default:
            break
        }
    }

    /// A tap on a preview that shows no camera has nothing to focus on.
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        guard let devicePoint = preview.devicePoint(atLayerPoint: point) else { return }
        onTap(point, devicePoint)
    }
}
#endif
