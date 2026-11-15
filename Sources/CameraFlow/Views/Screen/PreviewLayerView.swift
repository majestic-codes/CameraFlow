//
//  PreviewLayerView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import QuartzCore
import SwiftUI
import UIKit

/// A view that shows a camera preview and covers it with a still while the camera behind it changes, as the stock
/// camera covers its viewfinder when it switches cameras.
class PreviewLayerView: UIView, CameraPictureCover {
    let preview: any CameraPreview
    private var cover: PreviewCoverView?

    init(preview: any CameraPreview) {
        self.preview = preview
        super.init(frame: .zero)
        clipsToBounds = true
        layer.addSublayer(preview.layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.layer.frame = bounds
        CATransaction.commit()
        cover?.frame = bounds
    }

    /// The still is taken of the view as the screen shows it, a cover that is fading out included, so that it
    /// takes the place of the picture without a visible step.
    func coverPicture() {
        let still = snapshotView(afterScreenUpdates: false)
        cover?.removeFromSuperview()
        let cover = PreviewCoverView(still: still)
        cover.frame = bounds
        addSubview(cover)
        self.cover = cover
        if !UIAccessibility.isReduceMotionEnabled {
            cover.blurIn()
        }
    }

    func uncoverPicture() {
        guard let cover else { return }
        typealias Motion = CameraMotion.PictureCover
        let options: UIView.AnimationOptions = [.beginFromCurrentState, .curveEaseInOut]
        UIView.animate(withDuration: Motion.fadeDuration, delay: Motion.holdDuration, options: options) {
            cover.alpha = 0
        } completion: { [weak self] _ in
            // A cover that was replaced meanwhile is already gone, and the new one stays.
            guard let self, self.cover === cover else { return }
            cover.removeFromSuperview()
            self.cover = nil
        }
    }
}

/// A still of a camera's picture that fills its container, blurred for people who do not reduce motion. With
/// reduced motion the still stays sharp and the change of the camera is a plain cross-fade.
final class PreviewCoverView: UIView {
    private let still: UIView?
    private let stillSize: CGSize
    private let blurView = UIVisualEffectView(effect: nil)

    /// - Parameter still: The still to show, nil where the picture cannot be copied: the background of the screen
    ///   covers it then, with reduced motion too.
    init(still: UIView?) {
        self.still = still
        stillSize = still?.bounds.size ?? .zero
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        if let still {
            addSubview(still)
        } else {
            backgroundColor = UIColor(CameraPalette.background)
        }
        addSubview(blurView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        still?.frame = PreviewCoverLayout.stillFrame(stillSize: stillSize, in: bounds.size)
        blurView.frame = bounds
    }

    /// Blurs the still over `CameraMotion.PictureCover.blurDuration`.
    func blurIn() {
        UIView.animate(withDuration: CameraMotion.PictureCover.blurDuration) {
            self.blurView.effect = UIBlurEffect(style: .systemThinMaterialDark)
        }
    }
}
#endif
