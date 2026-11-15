//
//  FlowSymbolView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A system symbol of the flow in the current foreground style. The weight is medium, as the strokes of the
/// flow's own glyphs, unless the symbol is meant to be as light as the system draws it.
struct FlowSymbolView: View {
    let symbol: FlowSymbol
    let pointSize: CGFloat
    var weight = Font.Weight.medium

    var body: some View {
        Image(systemName: symbol.rawValue)
            .font(.system(size: pointSize, weight: weight))
            .accessibilityHidden(true)
    }
}
#endif
