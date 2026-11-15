//
//  ReviewStripTile.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The tile of a photo in the strip: its thumbnail in a circle, with a ring of the accent colour while the review
/// shows the photo and a dot with the Markup pen tip when something is drawn on it. The thumbnail stays upright as the
/// phone rotates.
struct ReviewStripPhotoTile: View {
    @Environment(\.flowLocalization) private var localization
    let photo: FlowPhoto
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        let metrics = FlowMetrics.Strip.self
        let diameter = CameraMetrics.SideButton.diameter
        Button(action: action) {
            Image(decorative: photo.thumbnail, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .rotatesWithDevice()
                .clipShape(Circle())
                .overlay(alignment: .topLeading) {
                    if isCurrent {
                        Circle()
                            .stroke(CameraPalette.accent, lineWidth: metrics.currentRingWidth)
                            .placed(in: ReviewStripLayout.currentRing)
                    } else {
                        Circle()
                            .stroke(CameraPalette.photoRim, lineWidth: metrics.rimWidth)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if photo.hasDrawing {
                        DrawingMark()
                            .placed(in: ReviewStripLayout.drawingMark)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(photo.hasDrawing ? ReviewText(localization).withDrawing : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// The dot of a photo with a drawing: the Markup pen tip on the accent colour, outlined against the photo under it.
private struct DrawingMark: View {
    var body: some View {
        let diameter = FlowMetrics.Strip.drawingMarkDiameter
        FlowSymbolView(symbol: .drawingMark, pointSize: FlowMetrics.MarkupSymbol.drawingMarkPointSize)
            .foregroundStyle(CameraPalette.onAccent)
            .rotatesWithDevice()
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(CameraPalette.accent))
            .overlay {
                Circle()
                    .stroke(CameraPalette.drawingMarkOutline, lineWidth: FlowMetrics.Strip.drawingMarkOutlineWidth)
            }
    }
}

/// The "+" at the end of the strip, a tile of the photos' own size. The glyph dims while the tile is disabled.
struct ReviewStripAddTile: View {
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let diameter = CameraMetrics.SideButton.diameter
        Button(action: action) {
            FlowGlyphView(glyph: .plus)
                .foregroundStyle(CameraPalette.label)
                .opacity(isEnabled ? 1 : CameraPalette.unavailableOpacity)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(CameraPalette.addTile))
                .overlay {
                    Circle()
                        .stroke(CameraPalette.photoRim, lineWidth: FlowMetrics.Strip.rimWidth)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(FlowMotion.availability, value: isEnabled)
    }
}
#endif
