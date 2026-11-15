//
//  FlowGlyphView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A glyph of the flow stroked in the current foreground style, centred in the space it is given.
struct FlowGlyphView: View {
    let glyph: FlowGlyph

    var body: some View {
        CenteredOutline(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: glyph.lineWidth, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// The outline of a glyph, which is drawn around the origin, moved to the centre of the space.
private struct CenteredOutline: Shape {
    let glyph: FlowGlyph

    func path(in bounds: CGRect) -> Path {
        Path(glyph.outline).offsetBy(dx: bounds.midX, dy: bounds.midY)
    }
}
#endif
