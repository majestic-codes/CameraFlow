//
//  MarkupTopBarLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The widths of the two labels of the drawing mode's top bar as they are set, which depend on the language.
struct MarkupLabelWidths: Equatable, Sendable {
    let cancel: CGFloat
    let done: CGFloat
}

/// Frames of the top bar of the drawing mode, in the coordinates of the whole screen: a capsule in each top corner
/// and the round undo and redo buttons between them. In a right-to-left language the bar is the mirror image, as
/// the system's own Markup is: "Cancel" in the right corner, undo right of redo, and their arrows the other way.
struct MarkupTopBarLayout: Equatable, Sendable {
    let screen: CameraScreenLayout
    let labelWidths: MarkupLabelWidths
    let isRightToLeft: Bool

    /// Undo, where the camera has the first of its two top bar buttons, or the second in a right-to-left language.
    var undo: CGRect {
        stepButton(at: isRightToLeft ? 1 : 0)
    }

    /// Redo, beside undo on its trailing side.
    var redo: CGRect {
        stepButton(at: isRightToLeft ? 0 : 1)
    }

    /// Where undo takes a touch: the round button, grown to the least size a finger needs around its centre.
    var undoTouchArea: CGRect {
        touchArea(around: undo)
    }

    var redoTouchArea: CGRect {
        touchArea(around: redo)
    }

    /// The arrow of undo, which points to the leading side: in a right-to-left language it is the arrow of redo,
    /// the mirror image.
    var undoGlyph: FlowGlyph {
        isRightToLeft ? .redo : .undo
    }

    var redoGlyph: FlowGlyph {
        isRightToLeft ? .undo : .redo
    }

    /// "Cancel", which starts where the trash of the review does.
    var cancel: CGRect {
        capsule(isTrailing: isRightToLeft, labelWidth: labelWidths.cancel)
    }

    /// "Done", which ends where the Markup button of the review does.
    var done: CGRect {
        capsule(isTrailing: !isRightToLeft, labelWidth: labelWidths.done)
    }

    /// A capsule in a top corner, on the line of the corner buttons of the review.
    private func capsule(isTrailing: Bool, labelWidth: CGFloat) -> CGRect {
        let corner = screen.cornerButton(isTrailing: isTrailing)
        guard isTrailing else {
            let width = capsuleWidth(labelWidth: labelWidth, room: stepButton(at: 0).minX - corner.minX)
            return CGRect(x: corner.minX, y: corner.minY, width: width, height: corner.height)
        }
        let width = capsuleWidth(labelWidth: labelWidth, room: corner.maxX - stepButton(at: 1).maxX)
        return CGRect(x: corner.maxX - width, y: corner.minY, width: width, height: corner.height)
    }

    /// A capsule is as wide as its label with the padding beside it, and no narrower than the least width. It
    /// stops short of the round button next to it, however long the label is: `room` is the space from the edge
    /// of the capsule to that button.
    private func capsuleWidth(labelWidth: CGFloat, room: CGFloat) -> CGFloat {
        let metrics = FlowMetrics.MarkupTopBar.self
        let fittedWidth = max(labelWidth + metrics.labelPadding * 2, metrics.minimumCapsuleWidth)
        return min(fittedWidth, max(room - metrics.stepButtonGap, 0))
    }

    /// The round button in a slot of the top bar, counted from the left.
    private func stepButton(at index: Int) -> CGRect {
        let slot = screen.topBarButton(at: index, of: 2)
        let center = CGPoint(x: slot.midX, y: slot.midY)
        return CameraScreenLayout.square(FlowMetrics.MarkupTopBar.stepButtonDiameter, center: center)
    }

    private func touchArea(around button: CGRect) -> CGRect {
        let side = max(button.width, FlowMetrics.MarkupTopBar.stepButtonTouchDiameter)
        return CameraScreenLayout.square(side, center: CGPoint(x: button.midX, y: button.midY))
    }
}
