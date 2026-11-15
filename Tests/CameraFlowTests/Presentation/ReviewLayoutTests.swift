//
//  ReviewLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The frames of the review on the 402 x 874 screen of the approved mock-up (`flowReview`, `strip` and `plusTile`
/// in `mock.js`).
@Suite("Review layout")
struct ReviewLayoutTests {
    let layout = LayoutWindow.referencePhone.layout(panelTileCount: 5)

    /// A frame of the strip's content on the screen, before the strip is scrolled.
    private func onScreen(_ frame: CGRect, of layout: CameraScreenLayout) -> CGRect {
        let strip = layout.reviewStrip(isRightToLeft: false).frame
        return frame.offsetBy(dx: strip.minX, dy: strip.minY)
    }

    // MARK: - Top bar

    @Test("The trash stands in the top leading corner at 38, 88 with a radius of 22")
    func trash() {
        expectClose(layout.reviewTrash, CGRect(x: 16, y: 66, width: 44, height: 44))
    }

    @Test("The Markup button stands in the top trailing corner at 364, 88, where the shooting mode flips the camera")
    func markup() {
        expectClose(layout.reviewMarkup, CGRect(x: 342, y: 66, width: 44, height: 44))
        #expect(layout.reviewMarkup == layout.flip)
    }

    @Test("In a right-to-left language the trash and the Markup button change corners, around the same counter")
    func rightToLeftTopBar() {
        let leftToRight = ReviewTopBarLayout(screen: layout, isRightToLeft: false)
        let rightToLeft = ReviewTopBarLayout(screen: layout, isRightToLeft: true)
        #expect(leftToRight.trash == layout.reviewTrash)
        #expect(leftToRight.markup == layout.reviewMarkup)
        #expect(rightToLeft.trash == layout.reviewMarkup)
        #expect(rightToLeft.markup == layout.reviewTrash)
        #expect(rightToLeft.counter == leftToRight.counter)
    }

    @Test("The counter is centred between the corner buttons, on their line")
    func counter() {
        let counter = layout.reviewCounter
        #expect(counter.midX == 201)
        expectClose(counter.midY, 88, tolerance: 0.34)
        #expect(counter.minX == layout.reviewTrash.maxX)
        #expect(counter.maxX == layout.reviewMarkup.minX)
    }

    // MARK: - Pages

    @Test(
        "The review shows its photo in the frame of the 4:3 viewfinder whatever the camera is set to",
        arguments: CameraFlowAspectRatio.allCases
    )
    func reviewedPhoto(aspectRatio: CameraFlowAspectRatio) {
        let layout = LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 5)
        expectClose(layout.reviewedPhoto, CGRect(x: 0, y: 128, width: 402, height: 536))
    }

    @Test("A page is the frame of the photo and a gap past its trailing edge, past the edge of the phone's screen")
    func pager() {
        let pager = layout.reviewPager
        let photo = layout.reviewedPhoto
        expectClose(photo, CGRect(x: 0, y: 128, width: 402, height: 536))
        #expect(pager.origin == photo.origin)
        #expect(pager.height == photo.height)
        #expect(pager.width == photo.width + FlowMetrics.ReviewPager.pageGap)
        #expect(pager.width > layout.size.width)
    }

    @Test("On every screen a page starts at the photo and has the gap past it", arguments: LayoutWindow.all)
    func pagerOnEveryScreen(window: LayoutWindow) {
        let layout = window.layout()
        let pager = layout.reviewPager
        let photo = layout.reviewedPhoto
        #expect(pager.origin == photo.origin)
        #expect(pager.size == CGSize(width: photo.width + FlowMetrics.ReviewPager.pageGap, height: photo.height))
    }

    // MARK: - Strip

    @Test("The strip is a band across the screen around the line of the shutter")
    func stripBand() {
        let strip = layout.reviewStrip(isRightToLeft: false).frame
        expectClose(strip, CGRect(x: 0, y: 692, width: 402, height: 56))
        #expect(strip.midY == layout.shutter.midY)
    }

    @Test(
        "The tiles are 48 pt circles, the first at x 34, centred on y 720 and 56 pt apart",
        arguments: [(0, 34.0), (1, 90.0), (4, 258.0)]
    )
    func tiles(index: Int, minX: Double) {
        let tile = layout.reviewStrip(isRightToLeft: false).tile(at: index, of: 6)
        expectClose(onScreen(tile, of: layout), CGRect(x: minX, y: 696, width: 48, height: 48))
    }

    @Test("The first tile stands where the shooting mode has its library button", arguments: LayoutWindow.all)
    func firstTile(window: LayoutWindow) {
        let layout = window.layout()
        let tile = layout.reviewStrip(isRightToLeft: false).tile(at: 0, of: 1)
        expectClose(onScreen(tile, of: layout), layout.library)
    }

    @Test("The \"+\" after five photos is centred at 338, 720")
    func addTile() {
        let tile = onScreen(layout.reviewStrip(isRightToLeft: false).tile(at: 5, of: 6), of: layout)
        #expect(tile.midX == 338)
        #expect(tile.midY == 720)
    }

    @Test(
        "In a right-to-left language the set runs from the right, its first tile on the mirror of the library button",
        arguments: 1...6
    )
    func rightToLeftStrip(count: Int) {
        let leftToRight = layout.reviewStrip(isRightToLeft: false)
        let rightToLeft = layout.reviewStrip(isRightToLeft: true)
        #expect(rightToLeft.frame == leftToRight.frame)
        #expect(rightToLeft.scrolledWidth(tileCount: count) == rightToLeft.frame.width)
        let mirroredLibrary = rightToLeft.frame.width - (layout.library.midX - rightToLeft.frame.minX)
        #expect(rightToLeft.tile(at: 0, of: count).midX == mirroredLibrary)
        for index in 0..<count {
            let tile = rightToLeft.tile(at: index, of: count)
            #expect(tile.midX == rightToLeft.frame.width - leftToRight.tile(at: index, of: count).midX)
            #expect(tile.minY == leftToRight.tile(at: index, of: count).minY)
            if index > 0 {
                #expect(rightToLeft.tile(at: index - 1, of: count).midX - tile.midX == FlowMetrics.Strip.pitch)
            }
        }
    }

    @Test("A right-to-left strip wider than the screen mirrors the tiles inside its content")
    func rightToLeftOverflow() {
        let leftToRight = layout.reviewStrip(isRightToLeft: false)
        let rightToLeft = layout.reviewStrip(isRightToLeft: true)
        let width = rightToLeft.scrolledWidth(tileCount: 8)
        #expect(width == leftToRight.contentWidth(tileCount: 8))
        #expect(width > rightToLeft.frame.width)
        for index in 0..<8 {
            #expect(rightToLeft.tile(at: index, of: 8) == leftToRight.tile(at: 7 - index, of: 8))
        }
        #expect(leftToRight.scrolledWidth(tileCount: 3) == leftToRight.contentWidth(tileCount: 3))
    }

    @Test("Five photos and the \"+\" fit the screen, and a sixth photo makes the strip scroll")
    func contentWidth() {
        let strip = layout.reviewStrip(isRightToLeft: false)
        #expect(strip.contentWidth(tileCount: 0) == 0)
        #expect(strip.contentWidth(tileCount: 1) == 116)
        #expect(strip.contentWidth(tileCount: 6) == 396)
        #expect(strip.contentWidth(tileCount: 6) <= strip.frame.width)
        #expect(strip.contentWidth(tileCount: 7) > strip.frame.width)
    }

    @Test("The ring of the current tile has a radius of 26.5 about the middle of the tile and fits the band")
    func currentRing() {
        let ring = ReviewStripLayout.currentRing
        expectClose(ring, CGRect(x: -2.5, y: -2.5, width: 53, height: 53))
        let outerRadius = ring.width / 2 + FlowMetrics.Strip.currentRingWidth / 2
        #expect(outerRadius * 2 <= layout.reviewStrip(isRightToLeft: false).frame.height)
    }

    @Test("The dot of a drawing has a radius of 8 at 41, 41 from the origin of its tile")
    func drawingMark() {
        expectClose(ReviewStripLayout.drawingMark, CGRect(x: 33, y: 33, width: 16, height: 16))
    }
}
