//
//  FormatPanelColumns.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Where the row labels and the columns of the options of the Format sub-panel start, in points from the leading
/// edge of its card.
///
/// The rows share their columns. The columns stand at the stock pitch wherever every option then fits its column
/// and the card, and the labels fit before them: the pitch for two columns, and the pitch of the stock glyph rows
/// for three. On a card too narrow for the words of a language, each column is as wide as its widest option and the
/// columns share what is left of the card between them, so the last option ends at the edge of the card. Options
/// that are still too wide move the first column towards the row labels, and the row labels towards the edge of the
/// card, as far as the leading edge of the back button above them.
struct FormatPanelColumns: Equatable, Sendable {
    /// The leading edge of the row labels.
    let labelLeading: CGFloat
    /// The leading edge of each column, the selection bullet of its options included.
    let leadings: [CGFloat]

    private typealias Metrics = CameraMetrics.FormatPanel

    /// - Parameters:
    ///   - optionWidths: The width of the widest option of each column, its selection bullet included.
    ///   - cardWidth: The width of the card of the sub-panel.
    ///   - labelWidth: The width of the widest row label.
    init(optionWidths: [CGFloat], cardWidth: CGFloat, labelWidth: CGFloat) {
        let stock = Self.stockLeadings(count: optionWidths.count)
        let end = cardWidth - Metrics.minimumGap
        let fitsStock = Self.fits(optionWidths, at: stock, end: end, labelWidth: labelWidth)
        guard fitsStock == false, optionWidths.count > 1 else {
            labelLeading = Metrics.labelLeading
            leadings = stock
            return
        }
        let gapCount = CGFloat(optionWidths.count - 1)
        let optionsWidth = optionWidths.reduce(0, +)
        let latestFirst = end - optionsWidth - gapCount * Metrics.minimumGap
        let latestLabelLeading = latestFirst - Metrics.minimumLabelGap - labelWidth
        let labelLeading = max(min(Metrics.labelLeading, latestLabelLeading), Self.leastLabelLeading)
        let labelsEnd = labelLeading + labelWidth + Metrics.minimumLabelGap
        let first = max(min(Metrics.firstColumnLeading, latestFirst), labelsEnd)
        let gap = max((end - first - optionsWidth) / gapCount, Metrics.minimumGap)
        var leading = first
        self.labelLeading = labelLeading
        leadings = optionWidths.map { width in
            defer { leading += width + gap }
            return leading
        }
    }

    /// Whether every option fits its column at these leadings and the last one ends by `end`, with the row labels
    /// at their stock place before the first column.
    private static func fits(
        _ optionWidths: [CGFloat],
        at leadings: [CGFloat],
        end: CGFloat,
        labelWidth: CGFloat
    ) -> Bool {
        let ends = zip(leadings, optionWidths).map { $0 + $1 }
        let limits = leadings.dropFirst().map { $0 - Metrics.minimumGap } + [end]
        let labelsEnd = Metrics.labelLeading + labelWidth + Metrics.minimumLabelGap
        return zip(ends, limits).allSatisfy { $0 <= $1 } && leadings.allSatisfy { labelsEnd <= $0 }
    }

    /// The farthest the row labels move towards the edge of the card: under the leading edge of the back button.
    static var leastLabelLeading: CGFloat {
        CameraMetrics.SubPanel.backButtonCenter.x - CameraMetrics.SubPanel.backButtonDiameter / 2
    }

    /// The columns at the stock pitch.
    static func stockLeadings(count: Int) -> [CGFloat] {
        let pitch = count > 2 ? Metrics.threeColumnPitch : Metrics.twoColumnPitch
        return (0..<count).map { Metrics.firstColumnLeading + CGFloat($0) * pitch }
    }

    /// The width of an option in its column: its selection bullet, the space after it and its word.
    static func optionWidth(textWidth: CGFloat) -> CGFloat {
        Metrics.bulletSize + Metrics.bulletGap + textWidth
    }
}
