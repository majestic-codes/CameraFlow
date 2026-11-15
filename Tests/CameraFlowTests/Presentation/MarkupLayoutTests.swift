//
//  MarkupLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The frames of the drawing mode on the 402 x 874 screen of the approved mock-up (`flowDraw` in `mock.js`).
@Suite("Markup layout")
struct MarkupLayoutTests {
    let screen = LayoutWindow.referencePhone.layout(panelTileCount: 5)

    /// The labels as the system font sets them in Ukrainian, the language of the mock-up.
    private static let ukrainianWidths = MarkupLabelWidths(cancel: 82.2, done: 52.9)
    /// The labels as the system font sets them in English.
    private static let englishWidths = MarkupLabelWidths(cancel: 51.5, done: 39.7)

    private func topBar(_ labelWidths: MarkupLabelWidths, isRightToLeft: Bool = false) -> MarkupTopBarLayout {
        MarkupTopBarLayout(screen: screen, labelWidths: labelWidths, isRightToLeft: isRightToLeft)
    }

    /// A frame reflected across the middle of the screen.
    private func mirrored(_ frame: CGRect) -> CGRect {
        CGRect(x: screen.size.width - frame.maxX, y: frame.minY, width: frame.width, height: frame.height)
    }

    // MARK: - Top bar

    /// Labels of the most different widths: the Ukrainian ones of the mock-up, the English ones and two long ones.
    private static let labelWidthCases = [ukrainianWidths, englishWidths, MarkupLabelWidths(cancel: 300, done: 300)]

    @Test(
        "Undo and redo stand at 179, 88 and 223, 88 with a radius of 20, whatever the labels are",
        arguments: labelWidthCases
    )
    func stepButtons(labelWidths: MarkupLabelWidths) {
        let layout = topBar(labelWidths)
        expectClose(layout.undo, CGRect(x: 159, y: 68, width: 40, height: 40))
        expectClose(layout.redo, CGRect(x: 203, y: 68, width: 40, height: 40))
    }

    @Test("In Ukrainian the capsules are the ones of the mock-up: 112 x 44 at 16, 66 and 90 x 44 at 296, 66")
    func ukrainianCapsules() {
        let layout = topBar(Self.ukrainianWidths)
        expectClose(layout.cancel, CGRect(x: 16, y: 66, width: 112, height: 44))
        expectClose(layout.done, CGRect(x: 296, y: 66, width: 90, height: 44))
    }

    @Test("In English both labels are short, so both capsules have the least width and keep their corners")
    func englishCapsules() {
        let layout = topBar(Self.englishWidths)
        expectClose(layout.cancel, CGRect(x: 16, y: 66, width: 90, height: 44))
        expectClose(layout.done, CGRect(x: 296, y: 66, width: 90, height: 44))
    }

    @Test("A capsule grows with its label from its corner of the screen")
    func growingCapsules() {
        let layout = topBar(MarkupLabelWidths(cancel: 90, done: 80))
        expectClose(layout.cancel, CGRect(x: 16, y: 66, width: 120, height: 44))
        expectClose(layout.done, CGRect(x: 276, y: 66, width: 110, height: 44))
    }

    @Test("However long its label is, a capsule stops 8 points short of the round button next to it")
    func longLabels() {
        let layout = topBar(MarkupLabelWidths(cancel: 300, done: 300))
        expectClose(layout.cancel, CGRect(x: 16, y: 66, width: 135, height: 44))
        expectClose(layout.done, CGRect(x: 251, y: 66, width: 135, height: 44))
        #expect(layout.cancel.maxX < layout.undo.minX)
        #expect(layout.done.minX > layout.redo.maxX)
    }

    @Test(
        "Undo and redo take a touch in 44 pt squares around their circles, which meet and leave the capsules free",
        arguments: [ukrainianWidths, MarkupLabelWidths(cancel: 300, done: 300)]
    )
    func stepButtonTouchAreas(labelWidths: MarkupLabelWidths) {
        let layout = topBar(labelWidths)
        expectClose(layout.undoTouchArea, CGRect(x: 157, y: 66, width: 44, height: 44))
        expectClose(layout.redoTouchArea, CGRect(x: 201, y: 66, width: 44, height: 44))
        #expect(layout.undoTouchArea.maxX <= layout.redoTouchArea.minX)
        #expect(layout.cancel.maxX < layout.undoTouchArea.minX)
        #expect(layout.done.minX > layout.redoTouchArea.maxX)
    }

    @Test(
        "In a right-to-left language the bar is the mirror image, with Cancel on the right",
        arguments: labelWidthCases
    )
    func rightToLeft(labelWidths: MarkupLabelWidths) {
        let leftToRight = topBar(labelWidths)
        let rightToLeft = topBar(labelWidths, isRightToLeft: true)
        expectClose(rightToLeft.cancel, mirrored(leftToRight.cancel))
        expectClose(rightToLeft.done, mirrored(leftToRight.done))
        expectClose(rightToLeft.undo, mirrored(leftToRight.undo))
        expectClose(rightToLeft.redo, mirrored(leftToRight.redo))
        expectClose(rightToLeft.undoTouchArea, mirrored(leftToRight.undoTouchArea))
        #expect(rightToLeft.cancel.minX > rightToLeft.done.maxX)
    }

    @Test("In a right-to-left language the arrows of undo and redo are turned")
    func rightToLeftArrows() {
        #expect(topBar(Self.englishWidths).undoGlyph == .undo)
        #expect(topBar(Self.englishWidths).redoGlyph == .redo)
        #expect(topBar(Self.englishWidths, isRightToLeft: true).undoGlyph == .redo)
        #expect(topBar(Self.englishWidths, isRightToLeft: true).redoGlyph == .undo)
    }

    @Test("The capsules start and end where the corner buttons of the review do, on their line")
    func corners() {
        let layout = topBar(Self.ukrainianWidths)
        #expect(layout.cancel.minX == screen.reviewTrash.minX)
        #expect(layout.done.maxX == screen.reviewMarkup.maxX)
        #expect(layout.cancel.minY == screen.reviewTrash.minY)
        #expect(layout.done.height == screen.reviewMarkup.height)
    }

    // MARK: - Canvas

    @Test(
        "The canvas covers exactly the rectangle the review shows the photo in",
        arguments: [
            (CGSize(width: 3024, height: 4032), CGRect(x: 0, y: 128, width: 402, height: 536)),
            (CGSize(width: 4032, height: 3024), CGRect(x: 0, y: 245.25, width: 402, height: 301.5)),
            (CGSize(width: 2268, height: 4032), CGRect(x: 50.25, y: 128, width: 301.5, height: 536)),
            (CGSize(width: 3024, height: 3024), CGRect(x: 0, y: 195, width: 402, height: 402))
        ]
    )
    func canvas(photoSize: CGSize, expected: CGRect) {
        let frame = screen.reviewedPhotoFrame(photoSize: photoSize)
        expectClose(frame, expected)
        let zoomLayout = PhotoZoomLayout(pageSize: screen.reviewedPhoto.size, photoSize: photoSize)
        #expect(frame.size == zoomLayout.fittedSize)
    }
}
