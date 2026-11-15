//
//  ZoomablePhotoPage.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// One photo of the review in its page: whole at first, zoomed by a pinch or a double tap and panned while it is
/// zoomed. What is drawn on the photo lies over it and moves with it.
///
/// The page is a scroll view inside the scroll view of the pager, the way the Photos app nests them: a fitted photo
/// has nothing to pan, so a swipe turns the page, and a zoomed photo takes the pan until it reaches its edge.
struct ZoomablePhotoPage: UIViewRepresentable {
    let image: CGImage
    /// The picture of what is drawn on the photo, which covers the whole of it. Nil for nothing.
    let drawingImage: CGImage?
    /// Whether the review shows this page. A page that is turned away goes back to its fitted size.
    let isCurrent: Bool
    /// Whether the photo zooms. A photo that does not goes back to its fitted size.
    let isZoomable: Bool
    /// Called when a pinch or a double tap zooms the photo and when one takes it back to its fitted size.
    let onZoomChange: (_ isZoomed: Bool) -> Void

    func makeUIView(context: Context) -> ZoomablePhotoScrollView {
        ZoomablePhotoScrollView()
    }

    func updateUIView(_ scrollView: ZoomablePhotoScrollView, context: Context) {
        scrollView.onZoomChange = onZoomChange
        scrollView.show(image)
        scrollView.showDrawing(drawingImage)
        scrollView.isZoomable = isZoomable
        if !isCurrent || !isZoomable {
            scrollView.resetZoom()
        }
    }
}

/// The scroll view of one page. Its content is the photo at its fitted size, which the scroll view zooms, with the
/// picture of its drawing stretched over it.
final class ZoomablePhotoScrollView: UIScrollView, UIScrollViewDelegate {
    var onZoomChange: ((_ isZoomed: Bool) -> Void)?
    /// Whether a pinch and a double tap zoom the photo.
    var isZoomable = true {
        didSet {
            pinchGestureRecognizer?.isEnabled = isZoomable
            doubleTapRecognizer.isEnabled = isZoomable
        }
    }

    private let photoView = UIImageView()
    private let drawingView = UIImageView()
    private let doubleTapRecognizer = UITapGestureRecognizer()
    /// The layout the photo was last fitted with, nil before the first one.
    private var fittedLayout: PhotoZoomLayout?
    private var isZoomed = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        delegate = self
        maximumZoomScale = FlowMetrics.PhotoZoom.maximumScale
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        addSubview(photoView)
        drawingView.frame = photoView.bounds
        drawingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        photoView.addSubview(drawingView)
        doubleTapRecognizer.addTarget(self, action: #selector(toggleZoom))
        doubleTapRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapRecognizer)
    }

    func show(_ image: CGImage) {
        guard photoView.image?.cgImage !== image else { return }
        photoView.image = UIImage(cgImage: image)
        setNeedsLayout()
    }

    func showDrawing(_ image: CGImage?) {
        guard drawingView.image?.cgImage !== image else { return }
        drawingView.image = image.map { UIImage(cgImage: $0) }
    }

    /// Takes the photo back to its fitted size at once and without reporting it, since the caller asked for it. An
    /// animation would report the zooming it passes through.
    func resetZoom() {
        guard zoomScale != minimumZoomScale else { return }
        isZoomed = false
        setZoomScale(minimumZoomScale, animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = photoView.image else { return }
        let layout = PhotoZoomLayout(pageSize: bounds.size, photoSize: image.size)
        // A zoomed photo keeps its frame: a finer picture of the same photo arrives while it is zoomed.
        guard layout != fittedLayout, zoomScale == minimumZoomScale else { return }
        fittedLayout = layout
        photoView.frame = CGRect(origin: .zero, size: layout.fittedSize)
        contentSize = layout.fittedSize
        centerPhoto()
    }

    private func centerPhoto() {
        guard let fittedLayout else { return }
        let margins = fittedLayout.centeringMargins(atZoomScale: zoomScale)
        contentInset = UIEdgeInsets(
            top: margins.height,
            left: margins.width,
            bottom: margins.height,
            right: margins.width
        )
    }

    @objc
    private func toggleZoom(_ doubleTap: UITapGestureRecognizer) {
        guard let fittedLayout else { return }
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            zoom(to: fittedLayout.doubleTapTarget(around: doubleTap.location(in: photoView)), animated: true)
        }
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        photoView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerPhoto()
        let isZoomedNow = zoomScale > minimumZoomScale
        guard isZoomedNow != isZoomed else { return }
        isZoomed = isZoomedNow
        onZoomChange?(isZoomedNow)
    }
}
#endif
