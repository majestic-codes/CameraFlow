//
//  MarkupCanvasView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

/// The view of a canvas: it keeps the engine's view at the size the canvas opened with and scales it into its own
/// bounds, whatever size they take later, as when an iPad turns or its window is resized. The engine never sees
/// its size change, so the drawing keeps the coordinates it is stored in and stays over the part of the photo it
/// was drawn on.
final class MarkupCanvasView: UIView {
    /// The engine's view and the size of the canvas, once the canvas is open.
    private var canvas: (view: UIView, size: CGSize)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows `engineView` as the canvas, `canvasSize` points large before it is scaled into the bounds.
    func show(_ engineView: UIView, canvasSize: CGSize) {
        engineView.autoresizingMask = []
        addSubview(engineView)
        canvas = (engineView, canvasSize)
        placeCanvas()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeCanvas()
    }

    private func placeCanvas() {
        guard let canvas, bounds.isEmpty == false else {
            return
        }
        let placement = MarkupCanvasPlacement(canvasSize: canvas.size, bounds: bounds)
        canvas.view.bounds = CGRect(origin: .zero, size: canvas.size)
        canvas.view.center = placement.center
        canvas.view.transform = placement.transform
    }
}
#endif
