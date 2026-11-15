//
//  FormatPanelLayoutTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Layout of the Format sub-panel")
struct FormatPanelLayoutTests {
    private typealias Metrics = CameraMetrics.FormatPanel

    @Test("The quality row and the size of a photo stand in the stock card, where the stock panel has its second row")
    func rows() {
        #expect(Metrics.formatBaseline == 88)
        #expect(Metrics.qualityBaseline == 132)
        expectClose(Metrics.photoSizeBaseline, 164.667, tolerance: 0.01)
        #expect(Metrics.photoSizeBaseline < CameraMetrics.SubPanel.height)
    }

    // MARK: - Columns

    @Test("Options that fit stand in the stock columns: 91.5 pt apart for two and 75 pt apart for three")
    func stockColumns() throws {
        let two = FormatPanelColumns(optionWidths: [40, 38], cardWidth: 359, labelWidth: 60)
        try #require(two.leadings.count == 2)
        expectClose(two.leadings[0], 155.333, tolerance: 0.01)
        expectClose(two.leadings[1], 246.833, tolerance: 0.01)
        #expect(two.labelLeading == Metrics.labelLeading)
        let three = FormatPanelColumns(optionWidths: [40, 60, 35], cardWidth: 359, labelWidth: 60)
        try #require(three.leadings.count == 3)
        expectClose(three.leadings[1], 230.333, tolerance: 0.01)
        expectClose(three.leadings[2], 305.333, tolerance: 0.01)
        #expect(three.leadings == FormatPanelColumns.stockLeadings(count: 3))
    }

    @Test("A last option too wide for the card sizes the columns to their options, up to the edge of the card")
    func narrowCard() throws {
        let widths: [CGFloat] = [60, 62, 58]
        let columns = FormatPanelColumns(optionWidths: widths, cardWidth: 359, labelWidth: 60)
        try #require(columns.leadings.count == widths.count)
        expectClose(columns.leadings[0], 155.333, tolerance: 0.01)
        expectClose(columns.leadings[2] + widths[2], 359 - Metrics.minimumGap, tolerance: 0.01)
        let gaps = [
            columns.leadings[1] - columns.leadings[0] - widths[0],
            columns.leadings[2] - columns.leadings[1] - widths[1]
        ]
        expectClose(gaps[0], gaps[1], tolerance: 0.01)
        #expect(gaps[0] >= Metrics.minimumGap)
        #expect(columns.labelLeading == Metrics.labelLeading)
        let wider = FormatPanelColumns(optionWidths: widths, cardWidth: 386, labelWidth: 60)
        #expect(wider.leadings == FormatPanelColumns.stockLeadings(count: 3))
    }

    @Test("An option wider than the stock pitch moves the columns after it")
    func wideMiddleOption() throws {
        let widths: [CGFloat] = [50, 80, 30]
        let columns = FormatPanelColumns(optionWidths: widths, cardWidth: 386, labelWidth: 60)
        try #require(columns.leadings.count == widths.count)
        #expect(columns.leadings[2] >= columns.leadings[1] + widths[1] + Metrics.minimumGap)
        #expect(columns.leadings[2] + widths[2] <= 386 - Metrics.minimumGap + 0.01)
    }

    @Test("Options too wide for the card move the first column towards the row labels, and no further")
    func widestOptions() throws {
        let widths: [CGFloat] = [66, 66, 62]
        let columns = FormatPanelColumns(optionWidths: widths, cardWidth: 359, labelWidth: 60)
        try #require(columns.leadings.count == widths.count)
        #expect(columns.leadings[0] < 155.333)
        expectClose(columns.leadings[1] - columns.leadings[0] - widths[0], Metrics.minimumGap, tolerance: 0.01)
        expectClose(columns.leadings[2] + widths[2], 359 - Metrics.minimumGap, tolerance: 0.01)
        #expect(columns.labelLeading == Metrics.labelLeading)
    }

    @Test("Options too wide for the card with the labels in their place move the labels towards the edge of the card")
    func labelsGiveWay() throws {
        let widths: [CGFloat] = [72, 70, 60]
        let columns = FormatPanelColumns(optionWidths: widths, cardWidth: 304, labelWidth: 50)
        try #require(columns.leadings.count == widths.count)
        #expect(columns.labelLeading < Metrics.labelLeading)
        #expect(columns.labelLeading >= FormatPanelColumns.leastLabelLeading)
        expectClose(columns.leadings[0], columns.labelLeading + 50 + Metrics.minimumLabelGap, tolerance: 0.01)
        expectClose(columns.leadings[2] + widths[2], 304 - Metrics.minimumGap, tolerance: 0.01)
        let leastLeading = CameraMetrics.SubPanel.backButtonCenter.x - CameraMetrics.SubPanel.backButtonDiameter / 2
        #expect(FormatPanelColumns.leastLabelLeading == leastLeading)
        let tooWide = FormatPanelColumns(optionWidths: [90, 90, 90], cardWidth: 304, labelWidth: 50)
        try #require(tooWide.leadings.count == 3)
        #expect(tooWide.labelLeading == FormatPanelColumns.leastLabelLeading)
        expectClose(tooWide.leadings[0], tooWide.labelLeading + 50 + Metrics.minimumLabelGap, tolerance: 0.01)
    }

    @Test("Labels too long for the stock place of the first column move the columns after them")
    func longLabels() throws {
        let widths: [CGFloat] = [40, 38]
        let columns = FormatPanelColumns(optionWidths: widths, cardWidth: 386, labelWidth: 100)
        try #require(columns.leadings.count == widths.count)
        #expect(columns.labelLeading == Metrics.labelLeading)
        expectClose(columns.leadings[0], Metrics.labelLeading + 100 + Metrics.minimumLabelGap, tolerance: 0.01)
        #expect(columns.leadings[1] >= columns.leadings[0] + widths[0] + Metrics.minimumGap)
    }

    @Test("A panel with one column or none keeps the stock place")
    func fewColumns() {
        #expect(FormatPanelColumns(optionWidths: [], cardWidth: 359, labelWidth: 60).leadings.isEmpty)
        #expect(FormatPanelColumns(optionWidths: [400], cardWidth: 359, labelWidth: 60).leadings == [155.333])
    }

    @Test("An option is as wide as its bullet, the space after the bullet and its word")
    func optionWidth() {
        #expect(FormatPanelColumns.optionWidth(textWidth: 30) == 30 + Metrics.bulletSize + Metrics.bulletGap)
    }
}
