//
//  MarkupCanvasPlacementTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// A canvas keeps the size of the frame it opened in, and the window it is shown in changes: an iPad turns or its
/// window is resized while the drawing mode is open.
@Suite("Placement of a canvas in a resized window")
struct MarkupCanvasPlacementTests {
    /// A window before and after it changed.
    struct WindowChange: Sendable, CustomTestStringConvertible {
        let name: String
        let opening: CameraScreenLayout
        let current: CameraScreenLayout

        var testDescription: String {
            name
        }
    }

    private static func layout(
        _ width: CGFloat,
        _ height: CGFloat,
        _ interfaceOrientation: CameraOrientation
    ) -> CameraScreenLayout {
        let size = CGSize(width: width, height: height)
        return CameraScreenLayout(
            size: size,
            safeAreaTop: 24,
            aspectRatio: .fourByThree,
            panel: .hidden,
            panelTileCount: 5,
            interfaceOrientation: interfaceOrientation
        )
    }

    static let changes = [
        WindowChange(
            name: "iPad 11 turned from portrait to landscape",
            opening: layout(834, 1210, .portrait),
            current: layout(1210, 834, .landscapeLeft)
        ),
        WindowChange(
            name: "iPad 11 turned from landscape to portrait",
            opening: layout(1210, 834, .landscapeLeft),
            current: layout(834, 1210, .portrait)
        ),
        WindowChange(
            name: "iPad 13 in landscape narrowed to half the screen in Split View",
            opening: layout(1376, 1032, .landscapeRight),
            current: layout(678, 1032, .landscapeRight)
        ),
        WindowChange(
            name: "Stage Manager window made smaller",
            opening: layout(1032, 1376, .portrait),
            current: layout(700, 900, .portrait)
        )
    ]

    /// A portrait and a landscape photo of the camera.
    static let photoSizes = [CGSize(width: 3024, height: 4032), CGSize(width: 4032, height: 3024)]

    @Test(
        "The canvas covers the photo's new frame whole, and each part of it the same part of the photo",
        arguments: changes,
        photoSizes
    )
    func windowChange(change: WindowChange, photoSize: CGSize) {
        let canvasSize = change.opening.reviewedPhotoFrame(photoSize: photoSize).size
        let frameSize = change.current.reviewedPhotoFrame(photoSize: photoSize).size
        let bounds = CGRect(origin: .zero, size: frameSize)
        let placement = MarkupCanvasPlacement(canvasSize: canvasSize, bounds: bounds)
        let canvas = CGRect(origin: .zero, size: canvasSize)
        expectClose(Self.place(canvas, of: placement), bounds)
        let canvasPart = Self.part(of: canvas)
        let photoPart = Self.part(of: bounds)
        expectClose(Self.place(canvasPart, of: placement), photoPart)
    }

    @Test("A canvas shown at the size it opened with stays as it is")
    func sameSize() {
        let bounds = CGRect(x: 0, y: 0, width: 402, height: 536)
        let placement = MarkupCanvasPlacement(canvasSize: bounds.size, bounds: bounds)
        #expect(placement.scale == 1)
        #expect(placement.center == CGPoint(x: 201, y: 268))
        #expect(placement.transform.isIdentity)
    }

    @Test(
        "Bounds whose proportions are off by a rounding keep the whole canvas inside them, in the middle",
        arguments: [
            (CGRect(x: 0, y: 0, width: 301, height: 400), CGRect(x: 0.5, y: 0, width: 300, height: 400)),
            (CGRect(x: 0, y: 0, width: 150, height: 201), CGRect(x: 0, y: 0.5, width: 150, height: 200))
        ]
    )
    func rounding(bounds: CGRect, expected: CGRect) {
        let canvas = CGRect(x: 0, y: 0, width: 300, height: 400)
        let placement = MarkupCanvasPlacement(canvasSize: canvas.size, bounds: bounds)
        expectClose(Self.place(canvas, of: placement), expected)
    }

    /// Where a part of the canvas lands in the bounds: the canvas is scaled about its middle, which stands at the
    /// centre of the placement, as UIKit moves a view by its bounds, centre and transform.
    private static func place(_ part: CGRect, of placement: MarkupCanvasPlacement) -> CGRect {
        let canvasSize = placement.canvasSize
        let toMiddle = CGAffineTransform(translationX: -canvasSize.width / 2, y: -canvasSize.height / 2)
        let toCenter = CGAffineTransform(translationX: placement.center.x, y: placement.center.y)
        let transform = toMiddle.concatenating(placement.transform).concatenating(toCenter)
        return part.applying(transform)
    }

    /// A small part of a rectangle away from its middle and its corners: from 20 to 30 percent across and from 60 to
    /// 75 percent down.
    private static func part(of rectangle: CGRect) -> CGRect {
        CGRect(
            x: rectangle.minX + rectangle.width * 0.2,
            y: rectangle.minY + rectangle.height * 0.6,
            width: rectangle.width * 0.1,
            height: rectangle.height * 0.15
        )
    }
}
