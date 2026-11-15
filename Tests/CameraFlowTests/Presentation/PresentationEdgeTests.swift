//
//  PresentationEdgeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Presentation at the edges: no travel, no movement, the far side of the dial", .temporaryDirectory)
struct PresentationEdgeTests {
    // MARK: - Mode switch

    @Test("A switch that has not been laid out yet has no travel: the thumb stays and the mode stays")
    func modeSwitchWithoutTravel() {
        let tracking = ModeSwitchTracking(travel: 0, canReachReview: true)
        #expect(tracking.progress(from: .shooting, translation: 40) == 0)
        #expect(tracking.progress(from: .review, translation: -40) == 0)
        #expect(tracking.proposedMode(from: .shooting, translation: 200, velocity: 900) == .shooting)
        #expect(tracking.proposedMode(from: .review, translation: -200, velocity: -900) == .review)
    }

    // MARK: - Dial

    private let center = CGPoint(x: 200, y: 200)
    private let bounds = CGRect(x: 0, y: 0, width: 400, height: 400)

    /// A finger on a circle of 150 pt around the centre of the dial.
    private var finger: DialDrag {
        let surface = DialSurface(scale: ZoomScale(range: 0.5...8), center: center, bounds: bounds, snapFactors: [])
        return DialDrag(surface: surface, radius: 150)
    }

    @Test(
        "The angle of a point is counted from the top of the dial, clockwise, between minus and plus a half turn",
        arguments: [(0.0, 0.0), (90.0, 90.0), (-90.0, -90.0), (170.0, 170.0), (-170.0, -170.0), (135.0, 135.0)]
    )
    func angle(degrees: Double, expected: Double) {
        let angle = DialTracker.angle(of: finger.point(degrees: degrees), center: center) * 180 / .pi
        expectClose(angle, expected, tolerance: 0.001)
    }

    @Test("A finger that passes the bottom of the dial turns it by the small step it made, in either direction")
    func acrossTheBottom() {
        let scale = ZoomScale(range: 0.5...8)
        let surface = DialSurface(scale: scale, center: center, bounds: bounds, snapFactors: [])
        var clockwise = DialTracker(point: finger.point(degrees: 179), time: 0)
        let zoomedOut = clockwise.move(to: finger.point(degrees: -179), time: 1, zoom: 2, on: surface)
        var counterClockwise = DialTracker(point: finger.point(degrees: -179), time: 0)
        let zoomedIn = counterClockwise.move(to: finger.point(degrees: 179), time: 1, zoom: 2, on: surface)
        // Two degrees of a quarter-turn sweep over four doublings.
        let step = pow(2, 4 * 2.0 / 90)
        expectClose(zoomedOut, 2 / step, tolerance: 0.01)
        expectClose(zoomedIn, 2 * step, tolerance: 0.01)
    }

    @Test("A finger that does not move leaves the zoom as it is")
    func noMovement() {
        let scale = ZoomScale(range: 0.5...8)
        let surface = DialSurface(scale: scale, center: center, bounds: bounds, snapFactors: [2])
        let start = finger.point(degrees: 10)
        var tracker = DialTracker(point: start, time: 0)
        #expect(tracker.move(to: start, time: 1, zoom: 1.7, on: surface) == 1.7)
        #expect(tracker.snapped == nil)
        #expect(DialTracker.perpendicularityDamping(from: start, to: start, center: center) == 1)
        #expect(DialTracker.perpendicularityDamping(from: start, to: center, center: center) == 1)
    }

    @Test("A finger on the centre of the dial snaps to nothing")
    func atTheCentre() {
        let scale = ZoomScale(range: 0.5...8)
        let surface = DialSurface(scale: scale, center: center, bounds: bounds, snapFactors: [2])
        let nearCentre = DialDrag(surface: surface, radius: 5).point(degrees: 0)
        var tracker = DialTracker(point: nearCentre, time: 0)
        let zoom = tracker.move(to: center, time: 1, zoom: 1.99, on: surface)
        #expect(tracker.snapped == nil)
        #expect(zoom.isFinite)
        #expect(scale.range.contains(zoom))
    }

    @Test("A dial with no radius ticks on its values all the same")
    func hapticsWithoutRadius() {
        let scale = ZoomScale(range: 0.5...8)
        var haptics = DialHaptics(labeledFactors: [0.5, 1, 2, 8], snapFactors: [1, 2], scale: scale, radius: 0)
        let ticks = [1.5, 2.1, 2.2].map { haptics.update(zoom: $0) }
        #expect(ticks == [false, true, false])
    }

    @Test("A dial strip with no width yet turns the zoom by a finite step")
    func dialWithoutWidth() {
        let narrow = CGRect(x: 200, y: 0, width: 0, height: 400)
        let start = finger.point(degrees: 10)
        let end = finger.point(degrees: 5)
        let acceleration = DialTracker.acceleration(from: start, to: end, elapsed: 1.0 / 60, bounds: narrow)
        #expect(acceleration.isFinite)
        let surface = DialSurface(scale: ZoomScale(range: 0.5...8), center: center, bounds: narrow, snapFactors: [])
        var tracker = DialTracker(point: start, time: 0)
        let zoom = tracker.move(to: end, time: 1.0 / 60, zoom: 1, on: surface)
        #expect(zoom.isFinite)
        #expect(zoom > 1)
    }

    // MARK: - A window not laid out yet

    @Test("A window with no size, or a tiny one, places no circle and gives the panel no scale", arguments: [
        CGSize.zero, CGSize(width: 1, height: 1), CGSize(width: 0, height: 874)
    ])
    func windowWithoutSize(size: CGSize) {
        let layout = CameraScreenLayout(size: size, safeAreaTop: 0, panel: .tiles, panelTileCount: 8)
        #expect(layout.dualCameraCirclePlacement == nil)
        let tile = layout.controlPanelTile(at: 7)
        for frame in [layout.column, layout.viewfinder, layout.notice, layout.controlPanel, tile] {
            let isFinite = [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
            #expect(isFinite, "\(frame)")
        }
        #expect(layout.controlPanelTileLabelWidth.isFinite)
    }

    // MARK: - Size of a photo

    private func estimate(format: CameraFlowOutputFormat) -> PhotoSizeEstimate {
        var output = CameraFlowOutput()
        output.format = format
        return PhotoSizeEstimate(
            cameraFrame: CGSize(width: 4032, height: 3024),
            aspectRatio: .fourByThree,
            format: .heif,
            encodesHEVC: true,
            output: output
        )
    }

    @Test("A quality at either end of the measured ones takes the value measured there")
    func measuredEnds() {
        let tables = PhotoSizeEstimate.EncodedBytesPerPixel.self
        #expect(estimate(format: .heic(quality: 1)).bytesPerPixel == tables.heic.last?.bytesPerPixel)
        #expect(estimate(format: .heic(quality: 0.05)).bytesPerPixel == tables.heic.first?.bytesPerPixel)
        #expect(estimate(format: .jpeg(quality: 0)).bytesPerPixel == tables.jpeg.first?.bytesPerPixel)
        #expect(estimate(format: .jpeg(quality: 1)).bytesPerPixel == tables.jpeg.last?.bytesPerPixel)
    }

    // MARK: - Text

    @Test("The Save tile and its indicator say whether saving is on")
    func librarySaveValue() async {
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false)
        let model = makeCaptureModel(service: RecordingCameraService(), librarySaving: saving)
        #expect(CameraSettingText(.system).value(of: .librarySave, in: model.settings) == "Off")
        await model.settings.select(isLibrarySavingEnabled: true)
        #expect(CameraSettingText(.system).value(of: .librarySave, in: model.settings) == "On")
    }

    @Test("The notice of the camera says what the circle left out when nothing else is wrong")
    func dualCameraNotice() {
        let model = makeCaptureModel(service: RecordingCameraService())
        #expect(model.notice.map(CameraNoticeText(.system).message) == nil)
        model.notices.showDualCameraNotice(.turnedOffUnderPressure)
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Front camera off to cool down")
        model.session.interrupted(by: .cameraInUseByAnotherClient)
        #expect(model.notice.map(CameraNoticeText(.system).message) == "Camera in use by another app")
    }
}
