//
//  PhotoZoomLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

@Suite("Photo zoom layout")
struct PhotoZoomLayoutTests {
    static let pageSize = CGSize(width: 402, height: 536)

    private func layout(photoSize: CGSize) -> PhotoZoomLayout {
        PhotoZoomLayout(pageSize: Self.pageSize, photoSize: photoSize)
    }

    @Test(
        "A fitted photo is whole and as large as the page takes it",
        arguments: [
            (CGSize(width: 3024, height: 4032), CGSize(width: 402, height: 536)),
            (CGSize(width: 4032, height: 3024), CGSize(width: 402, height: 301.5)),
            (CGSize(width: 1000, height: 1000), CGSize(width: 402, height: 402)),
            (CGSize(width: 900, height: 1600), CGSize(width: 301.5, height: 536))
        ]
    )
    func fittedSize(photoSize: CGSize, expected: CGSize) {
        #expect(layout(photoSize: photoSize).fittedSize == expected)
    }

    @Test(
        "A photo or a page without an area has no fitted size",
        arguments: [(CGSize.zero, pageSize), (CGSize(width: 4, height: 3), CGSize.zero)]
    )
    func emptySizes(photoSize: CGSize, pageSize: CGSize) {
        #expect(PhotoZoomLayout(pageSize: pageSize, photoSize: photoSize).fittedSize == .zero)
    }

    @Test("A fitted landscape photo is held in the middle of the page by margins above and below it")
    func marginsOfFittedPhoto() {
        let margins = layout(photoSize: CGSize(width: 4032, height: 3024)).centeringMargins(atZoomScale: 1)
        #expect(margins == CGSize(width: 0, height: 117.25))
    }

    @Test("The margins shrink as the photo grows, and a side that fills the page has none")
    func marginsOfZoomedPhoto() {
        let landscape = layout(photoSize: CGSize(width: 4032, height: 3024))
        #expect(landscape.centeringMargins(atZoomScale: 1.5) == CGSize(width: 0, height: 41.875))
        #expect(landscape.centeringMargins(atZoomScale: 2) == .zero)
        #expect(landscape.centeringMargins(atZoomScale: 4) == .zero)
    }

    @Test("A photo that fills its page has no margins at any scale")
    func marginsOfFillingPhoto() {
        let portrait = layout(photoSize: CGSize(width: 3024, height: 4032))
        #expect(portrait.centeringMargins(atZoomScale: 1) == .zero)
        #expect(portrait.centeringMargins(atZoomScale: 2.5) == .zero)
    }

    @Test("A double tap zooms to the part of the photo around the tap that fills the page at the double tap scale")
    func doubleTapTarget() {
        let layout = layout(photoSize: CGSize(width: 3024, height: 4032))
        let target = layout.doubleTapTarget(around: CGPoint(x: 100, y: 200))
        let scale = FlowMetrics.PhotoZoom.doubleTapScale
        #expect(target.midX == 100)
        #expect(target.midY == 200)
        #expect(target.width == Self.pageSize.width / scale)
        #expect(target.height == Self.pageSize.height / scale)
    }

    @Test("A double tap zooms in and a pinch zooms further, to four times the fitted size")
    func scales() {
        #expect(FlowMetrics.PhotoZoom.doubleTapScale > 1)
        #expect(FlowMetrics.PhotoZoom.doubleTapScale < FlowMetrics.PhotoZoom.maximumScale)
        #expect(FlowMetrics.PhotoZoom.maximumScale == 4)
    }
}
