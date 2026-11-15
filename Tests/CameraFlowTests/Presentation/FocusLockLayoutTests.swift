//
//  FocusLockLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// The stock badge tray and the AE/AF LOCK badge in it, on the 402 x 874 screen the stock camera was measured on.
@Suite("AE/AF LOCK badge layout")
struct FocusLockLayoutTests {
    /// The English badge: its text and the space on either side.
    private let englishLength: CGFloat = 97

    private func layout(_ aspectRatio: CameraFlowAspectRatio = .fourByThree) -> CameraScreenLayout {
        LayoutWindow.referencePhone.layout(aspectRatio: aspectRatio, panelTileCount: 6)
    }

    /// The frame a placement covers on screen, turned with the badge.
    private func frame(of placement: FocusLockBadgePlacement, height: CGFloat = 24) -> CGRect {
        let isAcross = placement.angle == 0 || abs(placement.angle) == 180
        let size = isAcross
            ? CGSize(width: placement.length, height: height)
            : CGSize(width: height, height: placement.length)
        return CGRect(
            x: placement.center.x - size.width / 2,
            y: placement.center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    @Test("The tray is the stock one: 40 pt across the top of the 4:3 viewfinder")
    func tray() {
        expectClose(layout().badgeTray, CGRect(x: 0, y: 128, width: 402, height: 40))
    }

    @Test("In a 16:9 viewfinder the tray starts below the line of the top bar it reaches up beside")
    func sixteenByNineTray() {
        let layout = layout(.sixteenByNine)
        #expect(layout.viewfinder.minY < layout.topLineBottom)
        #expect(layout.badgeTray.minY == layout.topLineBottom)
    }

    @Test(
        "The badge sits in the middle of its tray, which lies along the edge that is up for the user in landscape",
        arguments: [
            (CameraOrientation.portrait, CGPoint(x: 201, y: 148), 0.0),
            (.upsideDown, CGPoint(x: 201, y: 148), 180),
            (.landscapeLeft, CGPoint(x: 382, y: 396), 90),
            (.landscapeRight, CGPoint(x: 20, y: 396), -90)
        ]
    )
    func placement(orientation: CameraOrientation, center: CGPoint, angle: Double) {
        let placement = layout().focusLockBadge(
            length: englishLength,
            isDualCameraCircleShown: false,
            elementOrientation: orientation
        )
        #expect(placement == FocusLockBadgePlacement(center: center, length: englishLength, angle: angle))
        #expect(layout().viewfinder.contains(frame(of: placement)))
    }

    @Test("Beside the second camera's circle the badge keeps clear of it, moving off the middle only as far as it must")
    func besideTheCircle() {
        let layout = layout()
        let circle = layout.dualCameraCircle
        let inset = CameraMetrics.FocusLockBadge.edgeInset
        for length in [englishLength, 240] {
            let placement = layout.focusLockBadge(
                length: length,
                isDualCameraCircleShown: true,
                elementOrientation: .portrait
            )
            let badge = frame(of: placement)
            #expect(placement.length == length)
            #expect(badge.maxX <= circle.minX - inset + 0.001)
            #expect(badge.minX >= inset - 0.001)
            let isInTheMiddle = placement.center.x == layout.badgeTray.midX
            let isAtTheCircle = isClose(badge.maxX, to: circle.minX - inset, tolerance: 0.001)
            #expect(isInTheMiddle || isAtTheCircle)
        }
        let english = layout.focusLockBadge(
            length: englishLength,
            isDualCameraCircleShown: true,
            elementOrientation: .portrait
        )
        expectClose(english.center.x, layout.badgeTray.midX, tolerance: 0.5)
    }

    @Test("Along the trailing edge in landscape the badge keeps below the circle")
    func landscapeBesideTheCircle() {
        let layout = layout()
        let placement = layout.focusLockBadge(
            length: 500,
            isDualCameraCircleShown: true,
            elementOrientation: .landscapeLeft
        )
        let badge = frame(of: placement)
        let inset = CameraMetrics.FocusLockBadge.edgeInset
        #expect(badge.minY >= layout.dualCameraCircle.maxY + inset - 0.001)
        #expect(badge.maxY <= layout.viewfinder.maxY - inset + 0.001)
        #expect(badge.intersects(layout.dualCameraCircle) == false)
    }

    @Test("A badge longer than its tray takes the whole room between the ends, in the middle")
    func longerThanTheTray() {
        let window = LayoutWindow(name: "Slide Over", size: CGSize(width: 320, height: 1000), safeAreaTop: 24)
        let layout = window.layout()
        let placement = layout.focusLockBadge(
            length: 400,
            isDualCameraCircleShown: false,
            elementOrientation: .portrait
        )
        #expect(placement.length == layout.badgeTray.width - 2 * CameraMetrics.FocusLockBadge.edgeInset)
        #expect(placement.center.x == layout.badgeTray.midX)
    }

    @Test("The notice moves below the tray while the badge shows at the top, and keeps its row otherwise")
    func notice() {
        let layout = layout()
        let row = layout.notice
        let moved = layout.notice(
            isDualCameraCircleShown: false,
            isFocusLockBadgeShown: true,
            elementOrientation: .portrait
        )
        #expect(moved == CGRect(x: row.minX, y: layout.badgeTray.maxY, width: row.width, height: row.height))
        let badge = layout.focusLockBadge(
            length: englishLength,
            isDualCameraCircleShown: false,
            elementOrientation: .portrait
        )
        #expect(moved.intersects(frame(of: badge)) == false)
        #expect(row.intersects(frame(of: badge)))
        let hidden = layout.notice(
            isDualCameraCircleShown: false,
            isFocusLockBadgeShown: false,
            elementOrientation: .portrait
        )
        #expect(hidden == row)
        for orientation in [CameraOrientation.landscapeLeft, .landscapeRight] {
            let beside = layout.notice(
                isDualCameraCircleShown: false,
                isFocusLockBadgeShown: true,
                elementOrientation: orientation
            )
            #expect(beside == row)
        }
        let belowTheCircle = layout.notice(isDualCameraCircleShown: true)
        let withBadge = layout.notice(
            isDualCameraCircleShown: true,
            isFocusLockBadgeShown: true,
            elementOrientation: .portrait
        )
        #expect(withBadge == belowTheCircle)
    }
}
