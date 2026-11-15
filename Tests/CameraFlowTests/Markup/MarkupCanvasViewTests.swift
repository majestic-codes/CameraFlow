//
//  MarkupCanvasViewTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import CoreGraphics
import Testing
import UIKit
@testable import CameraFlow

/// The view a canvas is shown in, with a plain view standing for the engine's: the engine's view keeps the size the
/// canvas opened with, and UIKit scales it, and the touches on it, into the view's bounds.
@Suite("The view of a canvas")
@MainActor
struct MarkupCanvasViewTests {
    private static let canvasSize = CGSize(width: 300, height: 400)

    @Test("The engine's view covers the view at the size the canvas opens with")
    func opening() {
        let canvasView = MarkupCanvasView(frame: CGRect(origin: .zero, size: Self.canvasSize))
        let engineView = UIView()
        canvasView.show(engineView, canvasSize: Self.canvasSize)
        #expect(engineView.superview === canvasView)
        #expect(engineView.bounds == CGRect(origin: .zero, size: Self.canvasSize))
        #expect(engineView.transform.isIdentity)
        expectClose(canvasView.convert(engineView.bounds, from: engineView), canvasView.bounds)
    }

    @Test(
        "A resized view keeps the engine's view at the canvas's size, scaled over the whole view",
        arguments: [CGSize(width: 150, height: 200), CGSize(width: 600, height: 800)]
    )
    func resize(size: CGSize) {
        let canvasView = MarkupCanvasView(frame: CGRect(origin: .zero, size: Self.canvasSize))
        let engineView = UIView()
        canvasView.show(engineView, canvasSize: Self.canvasSize)
        canvasView.frame = CGRect(origin: .zero, size: size)
        canvasView.layoutIfNeeded()
        #expect(engineView.bounds == CGRect(origin: .zero, size: Self.canvasSize))
        expectClose(canvasView.convert(engineView.bounds, from: engineView), canvasView.bounds)
        // A touch a quarter across and three quarters down the view lands there on the canvas too.
        let touch = CGPoint(x: size.width / 4, y: size.height * 3 / 4)
        let canvasPoint = canvasView.convert(touch, to: engineView)
        let expected = CGPoint(x: Self.canvasSize.width / 4, y: Self.canvasSize.height * 3 / 4)
        expectClose(CGRect(origin: canvasPoint, size: .zero), CGRect(origin: expected, size: .zero))
    }

    @Test("A view laid out without an area leaves the engine's view where it was")
    func emptyBounds() {
        let canvasView = MarkupCanvasView(frame: CGRect(origin: .zero, size: Self.canvasSize))
        let engineView = UIView()
        canvasView.show(engineView, canvasSize: Self.canvasSize)
        canvasView.frame = .zero
        canvasView.layoutIfNeeded()
        #expect(engineView.bounds == CGRect(origin: .zero, size: Self.canvasSize))
        #expect(engineView.transform.isIdentity)
    }
}
#endif
