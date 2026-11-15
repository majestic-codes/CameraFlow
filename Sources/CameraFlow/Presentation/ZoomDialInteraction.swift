//
//  ZoomDialInteraction.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Observation

/// The touch that drives the lens row and the zoom dial: a tap picks a lens, a press held or dragged opens the
/// dial and turns it, a tap on a label of the open dial zooms there, and the dial closes a while after the
/// finger has lifted, or after the system has taken the touch away. Points are in the coordinates of the screen
/// layout.
@MainActor
@Observable
final class ZoomDialInteraction {
    /// The lens button under the finger, nil once the press has opened the dial.
    private(set) var pressedLensIndex: Int?

    @ObservationIgnored private let zoom: ZoomModel
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private var touch: Touch?
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?

    private typealias DialMetrics = CameraMetrics.ZoomDial

    private struct Touch {
        var press: LensZoomPress
        var tracker: DialTracker
    }

    init(zoom: ZoomModel, clock: any Clock<Duration> = ContinuousClock()) {
        self.zoom = zoom
        self.clock = clock
    }

    /// The finger went down or moved. `start` is where this touch began.
    func touchChanged(to location: CGPoint, from start: CGPoint, time: TimeInterval, in layout: CameraScreenLayout) {
        guard var current = touch else {
            let tracker = DialTracker(point: location, time: time)
            beginTouch(Touch(press: LensZoomPress(start: start), tracker: tracker), in: layout)
            return
        }
        if !zoom.isDialOpen {
            guard current.press.turnsDial(at: location) else {
                current.tracker = DialTracker(point: location, time: time)
                touch = current
                return
            }
            openDial()
        }
        let surface = DialSurface(
            scale: zoom.scale,
            center: layout.zoomDialCenter,
            bounds: layout.zoomDial,
            snapFactors: zoom.dialSnapFactors
        )
        let factor = current.tracker.move(to: location, time: time, zoom: zoom.factor, on: surface)
        touch = current
        zoom.turnDial(to: factor)
    }

    /// The finger lifted. `start` is where this touch began.
    func touchEnded(at location: CGPoint, from start: CGPoint, in layout: CameraScreenLayout) {
        openTask?.cancel()
        let press = touch?.press ?? LensZoomPress(start: start)
        let pressedIndex = pressedLensIndex
        touch = nil
        pressedLensIndex = nil
        guard zoom.isDialOpen else {
            if let pressedIndex, lensIndex(at: location, in: layout) == pressedIndex {
                zoom.selectLens(at: pressedIndex)
            }
            return
        }
        if press.isTap(endingAt: location), let factor = dialLabel(near: location, in: layout) {
            zoom.setZoom(factor)
            zoom.closeDial()
            return
        }
        closeDialAfterDelay()
    }

    /// The system took the touch away, so no lift follows: a press that has not opened the dial selects nothing
    /// and opens nothing, and an open dial closes a while later. The next touch starts afresh.
    func touchCancelled() {
        openTask?.cancel()
        guard touch != nil else { return }
        touch = nil
        pressedLensIndex = nil
        if zoom.isDialOpen {
            closeDialAfterDelay()
        }
    }

    /// Opens the dial for a touch that zooms from outside the control, such as a pinch on the viewfinder, and
    /// keeps it open until `releaseDial()`.
    func holdDialOpen() {
        closeTask?.cancel()
        openDial()
    }

    /// The touch that held the dial open has ended: the dial closes a while later, unless a finger is on the
    /// control.
    func releaseDial() {
        guard touch == nil, zoom.isDialOpen else { return }
        closeDialAfterDelay()
    }

    /// Drops the pending opening and closing of the dial, when the control goes away.
    func cancelTimers() {
        openTask?.cancel()
        closeTask?.cancel()
    }

    private func beginTouch(_ touch: Touch, in layout: CameraScreenLayout) {
        self.touch = touch
        closeTask?.cancel()
        if !zoom.isDialOpen {
            pressedLensIndex = lensIndex(at: touch.press.start, in: layout)
            openTask = Task { [weak self, clock] in
                do {
                    try await clock.sleep(for: DialMetrics.openDelay)
                    // A cancel that comes after the sleep ended still keeps the dial closed.
                    try Task.checkCancellation()
                } catch {
                    return
                }
                self?.openDial()
            }
        }
    }

    private func closeDialAfterDelay() {
        closeTask?.cancel()
        closeTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: DialMetrics.closeDelay)
            } catch {
                return
            }
            // A cancel after the sleep ended but before this point still lands here.
            guard !Task.isCancelled else { return }
            self?.zoom.closeDial()
        }
    }

    private func openDial() {
        openTask?.cancel()
        guard !zoom.isDialOpen else { return }
        pressedLensIndex = nil
        zoom.openDial()
    }

    /// The lens button at a point of the row, wherever the row has slid.
    private func lensIndex(at point: CGPoint, in layout: CameraScreenLayout) -> Int? {
        guard let activeIndex = zoom.activeLensIndex else { return nil }
        let row = LensRowLayout(row: layout.lensRow, lensCount: zoom.lenses.count, activeIndex: activeIndex)
        return row.lensIndex(at: point)
    }

    /// The factor of the dial label near a point, among the labels the dial shows: none on the arc its edges fade
    /// out.
    private func dialLabel(near point: CGPoint, in layout: CameraScreenLayout) -> CGFloat? {
        let geometry = ZoomDialGeometry(center: layout.zoomDialCenter, radius: DialMetrics.radius)
        return zoom.dialLabelFactors.first { factor in
            let angle = zoom.scale.angle(of: factor, current: zoom.factor)
            let center = geometry.point(at: angle, inset: DialMetrics.labelInset)
            let distance = hypot(point.x - center.x, point.y - center.y)
            let isShown = ZoomDialEdgeFade.visibility(at: center, center: geometry.center) > 0
            return isShown && distance <= DialMetrics.labelTapRadius
        }
    }
}
