//
//  CameraScreenLayout.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of every element of the camera screen, in the coordinates of the whole screen.
///
/// The frames depend on the screen size, the aspect ratio of the viewfinder, on what the control panel shows and on
/// how many tiles it holds: an open sub-panel lifts the lens row, the dial and the shutter.
///
/// A phone lays the camera out across its whole width. A larger screen, an iPad in either orientation, lays the same
/// arrangement out in a column in its middle, as wide as the top bar, the viewfinder and the controls under it fit
/// the height of the screen, and keeps the row of controls under the viewfinder as wide as on the widest phone.
/// A window too short for that arrangement narrows the column until the viewfinder fits under the top bar, and
/// shrinks the grid of tiles to fit too, so nothing leaves the window. The viewfinder is as wide as the picture the
/// camera shows: portrait while the interface stands portrait or upside down, landscape while the interface stands
/// in landscape.
struct CameraScreenLayout: Equatable, Sendable {
    let size: CGSize
    let safeAreaTop: CGFloat
    let aspectRatio: CameraFlowAspectRatio
    let panel: CameraPanelPresentation
    /// How many setting tiles the control panel holds.
    let panelTileCount: Int
    /// The quarter the interface stands in.
    let interfaceOrientation: CameraOrientation

    init(
        size: CGSize,
        safeAreaTop: CGFloat,
        aspectRatio: CameraFlowAspectRatio,
        panel: CameraPanelPresentation,
        panelTileCount: Int,
        interfaceOrientation: CameraOrientation
    ) {
        self.size = size
        self.safeAreaTop = safeAreaTop
        self.aspectRatio = aspectRatio
        self.panel = panel
        self.panelTileCount = panelTileCount
        self.interfaceOrientation = interfaceOrientation
    }

    // MARK: - Column

    /// Whether the picture of the camera is wider than tall on screen.
    var isViewfinderLandscape: Bool {
        switch interfaceOrientation {
        case .portrait, .upsideDown: false
        case .landscapeLeft, .landscapeRight: true
        }
    }

    /// The column the camera is laid out in: the whole screen of a phone, the middle of a larger screen. It is no
    /// wider than the 4:3 viewfinder can be between the top bar and the bottom of the window.
    var column: CGRect {
        let heightPerWidth = heightPerWidth(of: .fourByThree)
        let fittingWidth = (size.height - topBarBottom - CameraMetrics.Viewfinder.controlsHeight) / heightPerWidth
        let largestWidth = (size.height - topBarBottom) / heightPerWidth
        let preferredWidth = max(fittingWidth, min(CameraMetrics.Column.phoneWidth, largestWidth))
        let width = max(min(size.width, preferredWidth), 0)
        return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
    }

    /// The band of the controls under the viewfinder and of the control panel: the column, at most as wide as the
    /// widest phone.
    var controlsBand: CGRect {
        let frame = column
        let width = min(frame.width, CameraMetrics.Column.phoneWidth)
        return CGRect(x: frame.midX - width / 2, y: 0, width: width, height: size.height)
    }

    private var topBarBottom: CGFloat {
        safeAreaTop + CameraMetrics.TopBar.topBelowSafeArea + CameraMetrics.TopBar.buttonSize
    }

    /// The bottom of the line of the top bar, with the round buttons in its corners.
    var topLineBottom: CGFloat {
        max(topBarBottom, cornerButton(isTrailing: true).maxY)
    }

    /// Height per width of the picture of an aspect ratio as the viewfinder shows it.
    private func heightPerWidth(of ratio: CameraFlowAspectRatio) -> CGFloat {
        isViewfinderLandscape ? 1 / ratio.heightPerWidth : ratio.heightPerWidth
    }

    // MARK: - Viewfinder

    /// The 4:3 viewfinder, which the controls are arranged around whatever the aspect ratio is.
    var standardViewfinder: CGRect {
        let frame = column
        let height = frame.width * heightPerWidth(of: .fourByThree)
        return CGRect(x: frame.minX, y: standardViewfinderTop(height: height), width: frame.width, height: height)
    }

    /// The top of the 4:3 viewfinder of a height. It stands on the controls, as on the phones, with at most the gap
    /// of the tallest phone above it: a taller window shares the rest of its free height equally above and below
    /// it. A screen too short for the arrangement keeps the viewfinder whole under the top bar and lets the
    /// controls overlap it.
    private func standardViewfinderTop(height: CGFloat) -> CGFloat {
        let preferredTop = size.height - CameraMetrics.Viewfinder.controlsHeight - height
        let freeHeight = preferredTop - topBarBottom
        guard freeHeight < 0 else {
            let sharedHeight = max(freeHeight - CameraMetrics.Viewfinder.largestGapAbove, 0)
            return preferredTop - sharedHeight / 2
        }
        let lowestTop = max(size.height - height, 0)
        return min(topBarBottom, lowestTop)
    }

    var viewfinder: CGRect {
        let standard = standardViewfinder
        let heightPerWidth = heightPerWidth(of: aspectRatio)
        guard !isViewfinderLandscape else {
            // A landscape picture of any ratio fits inside the 4:3 one, in its middle.
            let width = min(standard.width, standard.height / heightPerWidth)
            let height = width * heightPerWidth
            return CGRect(x: standard.midX - width / 2, y: standard.midY - height / 2, width: width, height: height)
        }
        let top: CGFloat = switch aspectRatio {
        case .fourByThree: standard.minY
        case .sixteenByNine: max(standard.minY - CameraMetrics.Viewfinder.sixteenByNineRise, 0)
        case .square: standard.minY + CameraMetrics.Viewfinder.squareDrop
        }
        // A tall picture keeps within the screen and gets narrower where the column is too short for it.
        let width = min(standard.width, (size.height - top) / heightPerWidth)
        return CGRect(x: standard.midX - width / 2, y: top, width: width, height: width * heightPerWidth)
    }

    /// The self-timer digits, centred in the viewfinder.
    var countdown: CGRect {
        viewfinder
    }

    /// The row of the notice capsule, across the top of the viewfinder and below the line of the top bar, which a
    /// 16:9 viewfinder reaches up beside. The capsule hangs from the top of the row: it is one line high, and a
    /// notice of more lines grows it down.
    var notice: CGRect {
        let frame = viewfinder
        let style = CameraMetrics.Notice.self
        let top = max(frame.minY, topLineBottom) + style.top
        return CGRect(x: frame.minX, y: top, width: frame.width, height: style.height)
    }

    // MARK: - Top bar

    func topBarButton(at index: Int, of count: Int) -> CGRect {
        let side = CameraMetrics.TopBar.buttonSize
        let offset = (CGFloat(index) - CGFloat(count - 1) / 2) * CameraMetrics.TopBar.pitch
        let top = safeAreaTop + CameraMetrics.TopBar.topBelowSafeArea
        return CGRect(x: column.midX + offset - side / 2, y: top, width: side, height: side)
    }

    // MARK: - Zoom

    /// How far the lens row, the dial and the shutter are lifted: the stock lift while a sub-panel is open, as far
    /// as the dial stays below the line of the top bar of a short window.
    private var controlsLift: CGFloat {
        guard case .subPanel = panel else { return 0 }
        let room = zoomControlBottom - CameraMetrics.ZoomDial.visibleHeight - topLineBottom
        return min(CameraMetrics.SubPanel.controlsLift, max(room, 0))
    }

    /// Whether the lens row and the dial show. The grid of tiles hides them, a sub-panel shows them lifted.
    var showsZoomControl: Bool {
        panel != .tiles
    }

    /// Bottom edge the lens row hangs from.
    var controlsEdge: CGFloat {
        zoomControlBottom - controlsLift
    }

    /// Bottom edge of the zoom control at the bottom of the viewfinder, where no sub-panel moves it.
    private var zoomControlBottom: CGFloat {
        min(standardViewfinder.maxY, size.height - CameraMetrics.Viewfinder.controlsHeight)
    }

    var lensRow: CGRect {
        let rowSize = CameraMetrics.LensRow.size
        let centerY = controlsEdge - CameraMetrics.LensRow.centerAboveViewfinderBottom
        return CGRect(
            x: column.midX - rowSize.width / 2,
            y: centerY - rowSize.height / 2,
            width: rowSize.width,
            height: rowSize.height
        )
    }

    /// The strip of the zoom dial that takes touches: from the top of the disc, which rises with the lens row while
    /// a sub-panel is open, down to the bottom of the viewfinder.
    var zoomDial: CGRect {
        let top = controlsEdge - CameraMetrics.ZoomDial.visibleHeight
        let frame = column
        return CGRect(x: frame.minX, y: top, width: frame.width, height: zoomControlBottom - top)
    }

    var zoomDialCenter: CGPoint {
        CGPoint(x: column.midX, y: zoomDial.minY + CameraMetrics.ZoomDial.radius)
    }

    /// The whole disc of the zoom dial. It is drawn entire, so that nothing cuts it with a straight edge: the
    /// shutter, the bottom bar and the control panel card lie over it, and the black below the viewfinder hides it.
    var zoomDialDisc: CGRect {
        Self.square(CameraMetrics.ZoomDial.radius * 2, center: zoomDialCenter)
    }

    // MARK: - Bottom controls

    var shutter: CGRect {
        let diameter = CameraMetrics.Shutter.ringDiameter
        let centerY = size.height - CameraMetrics.Shutter.centerAboveBottom - controlsLift
        return Self.square(diameter, center: CGPoint(x: column.midX, y: centerY))
    }

    /// The round library button left of the shutter, where the stock camera shows macro or depth.
    var library: CGRect {
        sideButton(isTrailing: false, centerAboveBottom: CameraMetrics.SideButton.upperCenterAboveBottom)
    }

    var more: CGRect {
        sideButton(isTrailing: true, centerAboveBottom: CameraMetrics.SideButton.upperCenterAboveBottom)
    }

    // MARK: - Bottom bar

    /// The cross that leaves the flow, where the stock camera shows the last photo.
    var exit: CGRect {
        sideButton(isTrailing: false, centerAboveBottom: CameraMetrics.SideButton.lowerCenterAboveBottom)
    }

    /// The check mark that hands the set over, where the stock camera flips the camera.
    var accept: CGRect {
        sideButton(isTrailing: true, centerAboveBottom: CameraMetrics.SideButton.lowerCenterAboveBottom)
    }

    /// The capsule of the mode switch between the cross and the check mark, in the slot of the stock mode picker.
    var modeSwitch: CGRect {
        let gap = CameraMetrics.ModePicker.sideGap
        let minX = exit.maxX + gap
        return CGRect(x: minX, y: exit.minY, width: accept.minX - gap - minX, height: exit.height)
    }

    // MARK: - Helpers

    private func sideButton(isTrailing: Bool, centerAboveBottom: CGFloat) -> CGRect {
        let diameter = CameraMetrics.SideButton.diameter
        let inset = CameraMetrics.SideButton.sideInset + diameter / 2
        let band = controlsBand
        let centerX = isTrailing ? band.maxX - inset : band.minX + inset
        let center = CGPoint(x: centerX, y: size.height - centerAboveBottom)
        return Self.square(diameter, center: center)
    }

    static func square(_ side: CGFloat, center: CGPoint) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}
