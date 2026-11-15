//
//  SubPanelOptionGlyphRow.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// One option of a glyph row.
struct SubPanelOptionGlyphItem<Glyph: View>: Identifiable {
    /// The last part of the accessibility identifier.
    let name: String
    /// What accessibility reads for the option, in full.
    let label: String
    let isSelected: Bool
    let glyph: Glyph
    /// The text the glyph shows where it shows one, which Voice Control answers to as well as the label.
    var visibleText: String?
    let action: () -> Void

    var id: String { name }
}

/// A row of glyph options centred on the card, the selected one yellow and the others white.
struct SubPanelOptionGlyphRow<Glyph: View>: View {
    let items: [SubPanelOptionGlyphItem<Glyph>]
    /// Distance between the centres of neighbouring options.
    var pitch = CameraMetrics.SubPanel.optionPitch
    /// What a finger coming down on an option readies, such as the haptic of the choice. Nothing by default.
    var onTouchDown: () -> Void = {}

    var body: some View {
        SubPanelOptionCanvas {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button(action: item.action) {
                        item.glyph
                            .foregroundStyle(item.isSelected ? CameraPalette.accent : CameraPalette.label)
                            .frame(width: pitch, height: CameraMetrics.SubPanel.optionHitHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TouchDownButtonStyle(onTouchDown: onTouchDown))
                    .accessibilityIdentifier(CameraIdentifier.subPanelOption(item.name))
                    .accessibilityLabel(item.label)
                    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
                    .accessibilityInputLabels(inputLabels(of: item))
                    .showsLargeContent(item.label) {
                        item.glyph
                    }
                }
            }
            .subPanelCentered(centerY: CameraMetrics.SubPanel.optionCenterY)
        }
    }

    /// What Voice Control answers to: the text the option shows where it differs from the label, and the label.
    private func inputLabels(of item: SubPanelOptionGlyphItem<Glyph>) -> [String] {
        guard let visibleText = item.visibleText, visibleText != item.label else {
            return [item.label]
        }
        return [visibleText, item.label]
    }
}
#endif
