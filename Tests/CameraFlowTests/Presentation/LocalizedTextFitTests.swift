//
//  LocalizedTextFitTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The translations of the camera's controls in the places that have a fixed width: every language of the package
/// fits where the layout puts its text, down to the narrowest window, in the styles of `CameraTextStyle` and with
/// the frames of the layout. A text that the view sets smaller where it is too long fits at its smallest scale.
@Suite("Translations in the places of a fixed width", .serialized, .timeLimit(.minutes(2)))
struct LocalizedTextFitTests {
    static let languages = StringCatalog.languages.sorted()

    /// The narrowest window the package lays out: an iPad app in Slide Over.
    static let narrowestWindow = LayoutWindow.slideOver
    /// The narrowest phones, the iPhone SE and the iPhone mini.
    static let narrowPhone = LayoutWindow.phones[1]
    /// The narrowest screen of an iPhone with the stock camera this one copies.
    static let regularPhone = LayoutWindow(name: "iPhone 16e", size: CGSize(width: 390, height: 844), safeAreaTop: 47)
    /// The least space between two texts on a line, and between a text and the edge of its card.
    static let gap: CGFloat = 4

    private static let tiles = ["flash", "live", "aspect", "timer", "exposure", "format", "dualCamera", "librarySave"]
    /// The key of the full name of a setting whose tile has a short form of its name.
    private static let nameKeys = ["dualCamera": "camera.control.dualCamera"]

    /// Labels a language writes in capitals itself. Turkish capitals of "Live" would have a dotted İ.
    private static let writtenInCapitals: [String: Set<String>] = ["camera.setting.live": ["tr"]]

    private let catalog: StringCatalog

    init() throws {
        catalog = try StringCatalog.checkout()
    }

    @Test("The narrowest window is the narrowest of the windows the layout is checked in")
    func narrowestWindowIsTheNarrowest() {
        #expect(LayoutWindow.all.allSatisfy { $0.size.width >= Self.narrowestWindow.size.width })
    }

    @Test(
        "The marks of the medium and the low quality fit the slot of a top bar glyph",
        arguments: languages, ["camera.quality.medium.mark", "camera.quality.low.mark"]
    )
    func topBarMarks(language: String, key: String) throws {
        let ruler = TextRuler(.topBarValue)
        let mark = try catalog.text(key, in: language)
        #expect(mark == mark.uppercased(with: Locale(identifier: language)), "\(mark)")
        expectFit(mark, ruler, within: CameraMetrics.TopBar.buttonSize - 2, "top bar")
    }

    @Test("The marks of the medium and the low quality differ", arguments: languages)
    func topBarMarksDiffer(language: String) throws {
        let medium = try catalog.text("camera.quality.medium.mark", in: language)
        let low = try catalog.text("camera.quality.low.mark", in: language)
        #expect(medium != low)
    }

    @Test(
        "The full name of a setting fits its line in the sub-panel: whole on a phone, at its smallest scale at 320 pt",
        arguments: languages
    )
    func settingTitles(language: String) throws {
        let ruler = TextRuler(.subPanelTitle, tracking: LetterTracking(language: language))
        for tile in Self.tiles {
            let title = try catalog.capitals(Self.nameKeys[tile] ?? "camera.setting.\(tile)", in: language)
            expectFitInSubPanel(title, ruler, "sub-panel title")
        }
    }

    @Test("A tile label fits its width under the tile, at its smallest scale at 320 pt", arguments: languages)
    func tileLabels(language: String) throws {
        let ruler = TextRuler(.tileLabel, tracking: LetterTracking(language: language))
        let narrowestRoom = Self.narrowestWindow.layout(panel: .tiles).controlPanelTileLabelWidth
        let rooms = LayoutWindow.all.map { $0.layout(panel: .tiles).controlPanelTileLabelWidth }
        #expect(rooms.allSatisfy { $0 >= narrowestRoom })
        for tile in Self.tiles {
            let label = try catalog.capitals("camera.setting.\(tile)", in: language)
            let scale = CameraMetrics.ControlPanel.labelMinimumScale
            expectFit(label, ruler, within: narrowestRoom, scale: scale, "tile in the narrowest window")
        }
    }

    /// Checks a line of the sub-panel: whole on the narrowest phone, at its smallest scale in the narrowest window.
    private func expectFitInSubPanel(
        _ text: String,
        _ ruler: TextRuler,
        _ place: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let scale = CameraMetrics.SubPanel.textMinimumScale
        let phoneLine = Self.narrowPhone.layout(panel: .subPanel(.flash)).subPanelTextLine(centeredAt: 0, height: 1)
        let line = Self.narrowestWindow.layout(panel: .subPanel(.flash)).subPanelTextLine(centeredAt: 0, height: 1)
        expectFit(text, ruler, within: phoneLine.width, "\(place) on a phone", sourceLocation: sourceLocation)
        let narrowestPlace = "\(place) in the narrowest window"
        expectFit(text, ruler, within: line.width, scale: scale, narrowestPlace, sourceLocation: sourceLocation)
    }

    @Test("The value of a setting fits its sub-panel, as the large value and as an option", arguments: languages)
    func settingValues(language: String) throws {
        let valueRuler = TextRuler(.subPanelValue)
        let optionRuler = TextRuler(.formatOption)
        for key in ["camera.value.on", "camera.value.off", "camera.value.auto", "camera.value.seconds"] {
            for text in try catalog.texts(key, in: language, number: "10") {
                expectFitInSubPanel(text, valueRuler, "sub-panel value")
            }
        }
        for key in ["camera.value.on", "camera.value.off"] {
            let option = try catalog.text(key, in: language)
            expectFit(option, optionRuler, within: CameraMetrics.SubPanel.wordOptionPitch - Self.gap, "option")
        }
    }

    /// The widths of the Format rows in a language: the widest row label, and the widest word of each column as
    /// the panel lays them out, a format or a quality.
    private func formatRowWidths(in language: String) throws -> (labelWidth: CGFloat, wordWidths: [CGFloat]) {
        let labelRuler = TextRuler(.formatRowLabel, tracking: LetterTracking(language: language))
        let optionRuler = TextRuler(.formatOption)
        let labelWidths = try ["camera.setting.format", "camera.setting.quality"].map { key in
            labelRuler.width(of: try catalog.capitals(key, in: language))
        }
        let qualities = try ["camera.quality.high", "camera.quality.medium", "camera.quality.low"].map { key in
            optionRuler.width(of: try catalog.text(key, in: language))
        }
        let formats = ["HEIF", "RAW"].map(optionRuler.width)
        let wordWidths = [max(formats[0], qualities[0]), max(formats[1], qualities[1]), qualities[2]]
        return (labelWidths.reduce(0, max), wordWidths)
    }

    @Test(
        "The rows of the Format sub-panel hold their labels and the three qualities in the window",
        arguments: languages, [narrowestWindow, narrowPhone, regularPhone]
    )
    func formatRows(language: String, window: LayoutWindow) throws {
        let (labelWidth, wordWidths) = try formatRowWidths(in: language)
        // The widths as wide as the phone may set them, which the columns are laid out for here.
        let margin = TextRuler.platformMargin
        let optionWidths = wordWidths.map { FormatPanelColumns.optionWidth(textWidth: $0 / margin) }
        let phoneLabelWidth = labelWidth / margin
        let card = window.layout(panel: .subPanel(.format)).subPanel
        let columns = FormatPanelColumns(optionWidths: optionWidths, cardWidth: card.width, labelWidth: phoneLabelWidth)
        let labelsEnd = columns.labelLeading + phoneLabelWidth + CameraMetrics.FormatPanel.minimumLabelGap
        try #require(columns.leadings.count == optionWidths.count)
        #expect(columns.labelLeading >= FormatPanelColumns.leastLabelLeading)
        #expect(columns.leadings[0] >= labelsEnd - 0.01, "the labels end at \(labelsEnd) pt")
        let ends = zip(columns.leadings, optionWidths).map { $0 + $1 }
        let limits = columns.leadings.dropFirst().map { $0 - Self.gap } + [card.width - Self.gap]
        for (column, (end, limit)) in zip(ends, limits).enumerated() {
            #expect(end <= limit + 0.01, "column \(column) ends at \(end) pt of \(limit) pt")
        }
    }

    @Test("On the screens of the stock camera the Format rows keep the stock places", arguments: languages)
    func formatRowsStockPlaces(language: String) throws {
        let (labelWidth, wordWidths) = try formatRowWidths(in: language)
        let regularCard = Self.regularPhone.layout(panel: .subPanel(.format)).subPanel
        let regular = FormatPanelColumns(
            optionWidths: wordWidths.map { FormatPanelColumns.optionWidth(textWidth: $0) },
            cardWidth: regularCard.width,
            labelWidth: labelWidth
        )
        #expect(regular.leadings == FormatPanelColumns.stockLeadings(count: 3))
        #expect(regular.labelLeading == CameraMetrics.FormatPanel.labelLeading)
    }

    @Test("The lines under the options of a sub-panel fit the card of the narrowest window", arguments: languages)
    func footnotes(language: String) throws {
        let ruler = TextRuler(.formatFootnote)
        let card = Self.narrowestWindow.layout(panel: .subPanel(.format)).subPanel
        for key in ["camera.format.photoSize", "camera.save.library"] {
            for text in try catalog.texts(key, in: language, number: "48") {
                expectFit(text, ruler, within: card.width - 2 * Self.gap, "footnote")
            }
        }
    }

    @Test("A current zoom below ten fits the active lens button in the form of every language", arguments: languages)
    func currentZoom(language: String) {
        let ruler = TextRuler(.zoomFactor, letterSpacing: CameraTextStyle.zoomFactor.tracking)
        let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
        let title = ZoomFactorTitle.current(8.8, localization: localization)
        expectFit(title, ruler, within: CameraMetrics.LensRow.buttonDiameter, "lens button")
    }

    @Test("A label the code shows in capitals is not written in capitals in the catalog", arguments: languages)
    func capitalsComeFromTheCode(language: String) throws {
        let locale = Locale(identifier: language)
        let keys = Self.tiles.map { "camera.setting.\($0)" } + Self.nameKeys.values
            + ["camera.setting.quality", "flow.mode.shooting", "flow.mode.review"]
        for key in keys {
            let text = try catalog.text(key, in: language)
            let hasCase = text.uppercased(with: locale) != text.lowercased(with: locale)
            let isWrittenInCapitals = hasCase && text == text.uppercased(with: locale)
            let mayBeWrittenInCapitals = Self.writtenInCapitals[key]?.contains(language) ?? false
            #expect(isWrittenInCapitals == mayBeWrittenInCapitals, "\(key): \(text)")
        }
    }
}
#endif
