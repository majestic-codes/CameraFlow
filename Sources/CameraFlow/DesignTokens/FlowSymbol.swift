//
//  FlowSymbol.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The glyphs of the flow that are the system's own symbols, by their names, where a glyph has to be the one the
/// user knows from the system. The flow's other glyphs are the outlines of `FlowGlyph`.
enum FlowSymbol: String, CaseIterable {
    /// The circled pen tip of Markup, as on the Markup button of Quick Look.
    case markup = "pencil.tip.crop.circle"
    /// The pen tip alone, for the dot of a photo with a drawing, where a circled one is unreadable.
    case drawingMark = "pencil.tip"
    /// The frame of the toggle of the second camera's circle, a rounded square that a dot completes.
    case dualCameraFrame = "app"
    /// A photo with an arrow into it, for saving to the photo library: the indicator, the tile and the options.
    case librarySave = "photo.badge.arrow.down"
}
