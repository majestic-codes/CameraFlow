//
//  CameraScreenLayout+ControlPanel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Frames of the control panel: the card with the setting tiles, the sub-panel of one setting, and the glass card
/// that changes between them.
extension CameraScreenLayout {
    // MARK: - Tiles

    /// The card with the setting tiles. The stock card has three rows; this one keeps its paddings and has as many
    /// rows as its tiles fill. A window too short for it between the line of the top bar and the bottom inset gets
    /// it shrunk to fit, by `controlPanelScale`.
    var controlPanel: CGRect {
        card(height: stockControlPanelHeight * controlPanelScale)
    }

    /// How much the grid of tiles is shrunk: 1, unless the window is too short for the stock card. Then the card's
    /// height, the tiles and their spacing shrink together, so the grid fits below the top bar.
    var controlPanelScale: CGFloat {
        let room = size.height - CameraMetrics.ControlPanel.bottomInset - topLineBottom
        let height = stockControlPanelHeight
        guard height > room else { return 1 }
        return max(room, 0) / height
    }

    /// The height of the card of the tiles at the stock paddings and pitch.
    private var stockControlPanelHeight: CGFloat {
        let metrics = CameraMetrics.ControlPanel.self
        let rows = (panelTileCount + metrics.columns - 1) / metrics.columns
        let rowsHeight = CGFloat(rows - 1) * metrics.rowPitch
        return metrics.firstRowCenter + rowsHeight + metrics.lastRowCenterAboveBottom
    }

    var controlPanelGrabber: CGRect {
        let grabber = CameraMetrics.ControlPanel.grabberSize
        let top = controlPanel.minY + CameraMetrics.ControlPanel.grabberTop * controlPanelScale
        return CGRect(x: column.midX - grabber.width / 2, y: top, width: grabber.width, height: grabber.height)
    }

    /// The strip along the top of the card that takes the drag of the grabber.
    var controlPanelGrabberTouchArea: CGRect {
        let card = controlPanel
        let height = CameraMetrics.ControlPanel.grabberTouchHeight * controlPanelScale
        return CGRect(x: card.minX, y: card.minY, width: card.width, height: height)
    }

    /// Distance between the centres of two neighbouring columns of tiles: the stock pitch, or less on a card too
    /// narrow for the tiles at the stock pitch, such as the card of a 320 pt window.
    var controlPanelColumnPitch: CGFloat {
        let metrics = CameraMetrics.ControlPanel.self
        let scale = controlPanelScale
        let gapCount = CGFloat(metrics.columns - 1)
        let fittingPitch = (controlPanel.width - metrics.tileSize.width * scale) / gapCount
        return max(min(metrics.columnPitch * scale, fittingPitch), 0)
    }

    /// The cell of the tile at an index of the grid, which fills row by row.
    func controlPanelTile(at index: Int) -> CGRect {
        let metrics = CameraMetrics.ControlPanel.self
        let scale = controlPanelScale
        let center = controlPanelTileCircleCenter(at: index)
        return CGRect(
            x: center.x - metrics.tileSize.width * scale / 2,
            y: center.y - metrics.tileCircleDiameter * scale / 2,
            width: metrics.tileSize.width * scale,
            height: metrics.tileSize.height * scale
        )
    }

    /// Centre of the circle of the tile at an index of the grid, which fills row by row.
    func controlPanelTileCircleCenter(at index: Int) -> CGPoint {
        let metrics = CameraMetrics.ControlPanel.self
        let gridColumn = index % metrics.columns
        let row = index / metrics.columns
        let columnOffset = CGFloat(gridColumn) - CGFloat(metrics.columns - 1) / 2
        let rowCenter = metrics.firstRowCenter + CGFloat(row) * metrics.rowPitch
        return CGPoint(
            x: column.midX + columnOffset * controlPanelColumnPitch,
            y: controlPanel.minY + rowCenter * controlPanelScale
        )
    }

    /// The width a tile label has under its circle, in the points of a tile at its stock size: two labels side by
    /// side keep the label spacing between them, and a label of the outer columns keeps it from the edge of the
    /// card. A longer label is set smaller.
    var controlPanelTileLabelWidth: CGFloat {
        let metrics = CameraMetrics.ControlPanel.self
        let scale = controlPanelScale
        guard scale > 0 else { return 0 }
        let edgeDistance = controlPanelTileCircleCenter(at: 0).x - controlPanel.minX
        let besideNeighbour = controlPanelColumnPitch / scale - metrics.labelSpacing
        let insideCard = 2 * (edgeDistance / scale - metrics.labelSpacing)
        return max(min(besideNeighbour, insideCard), 0)
    }

    // MARK: - Sub-panel

    /// The lower card that replaces the tiles while one setting is open.
    var subPanel: CGRect {
        card(height: CameraMetrics.SubPanel.height)
    }

    var subPanelBackButton: CGRect {
        let center = CameraMetrics.SubPanel.backButtonCenter
        let origin = subPanel.origin
        let screenCenter = CGPoint(x: origin.x + center.x, y: origin.y + center.y)
        return Self.square(CameraMetrics.SubPanel.backButtonDiameter, center: screenCenter)
    }

    /// Where the back button takes a touch: its circle grown to the size a finger needs, around the same centre.
    var subPanelBackTouchArea: CGRect {
        let button = subPanelBackButton
        let side = max(button.width, CameraMetrics.SubPanel.backButtonTouchDiameter)
        return Self.square(side, center: CGPoint(x: button.midX, y: button.midY))
    }

    /// A line of text centred across the sub-panel card, clear of the back button on either side, centred on the
    /// middle of its capitals. A longer text is set smaller.
    func subPanelTextLine(centeredAt offset: CGFloat, height: CGFloat) -> CGRect {
        let metrics = CameraMetrics.SubPanel.self
        let card = subPanel
        let inset = metrics.backButtonCenter.x + metrics.backButtonDiameter / 2 + metrics.textSpacing
        let width = max(card.width - 2 * inset, 0)
        return CGRect(x: card.midX - width / 2, y: card.minY + offset - height / 2, width: width, height: height)
    }

    // MARK: - Card

    /// The glass card in its current shape: the tiles, the sub-panel, or the closed blob around the shutter
    /// that the card grows from and shrinks into.
    var panelCard: CGRect {
        switch panel {
        case .hidden: seedCard
        case .tiles: controlPanel
        case .subPanel: subPanel
        }
    }

    /// The closed card, the blob around the shutter.
    private var seedCard: CGRect {
        let seed = CameraMetrics.ControlPanel.seedSize
        let center = CGPoint(x: column.midX, y: size.height - CameraMetrics.Shutter.centerAboveBottom)
        let origin = CGPoint(x: center.x - seed.width / 2, y: center.y - seed.height / 2)
        return CGRect(origin: origin, size: seed)
    }

    /// A card of a height at the bottom of the band of the controls.
    private func card(height: CGFloat) -> CGRect {
        let inset = CameraMetrics.ControlPanel.sideInset
        let bottom = size.height - CameraMetrics.ControlPanel.bottomInset
        let band = controlsBand
        return CGRect(x: band.minX + inset, y: bottom - height, width: band.width - inset * 2, height: height)
    }
}
