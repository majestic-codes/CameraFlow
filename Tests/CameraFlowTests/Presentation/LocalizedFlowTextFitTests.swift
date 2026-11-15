//
//  LocalizedFlowTextFitTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The translations of the notices and of the flow's own controls in the places that have a fixed width, down to the
/// narrowest window: a notice wraps to its second line, or to its third at the largest text size, and a label of the
/// mode switch or of the drawing mode shrinks no further than its smallest scale.
@Suite("Translations of the notices and of the flow's controls", .serialized, .timeLimit(.minutes(2)))
struct LocalizedFlowTextFitTests {
    static let languages = LocalizedTextFitTests.languages

    private static let narrowestWindow = LocalizedTextFitTests.narrowestWindow
    private static let narrowPhone = LocalizedTextFitTests.narrowPhone
    private static let regularPhone = LocalizedTextFitTests.regularPhone
    private static let gap = LocalizedTextFitTests.gap

    /// The messages of a camera that does not run, which the viewfinder shows in a block of its own.
    private static let failureKeys: Set<String> = [
        "camera.notice.accessDenied", "camera.notice.accessRestricted", "camera.notice.openSettings",
        "camera.notice.retry"
    ]

    /// The lines a notice takes at most at the default text size, which the capsule was laid out for.
    private static let defaultSizeLineCount = 2
    /// The weight Bold Text sets a notice in: SwiftUI draws the medium system font of the notice as bold, as it draws
    /// a light one as regular and a regular one as semibold (`CameraGlyphView`).
    private static let boldTextWeight: CGFloat = 0.4

    private let catalog: StringCatalog

    init() throws {
        catalog = try StringCatalog.checkout()
    }

    @Test(
        "A notice fits two lines over the viewfinder of the narrowest window, set bolder by Bold Text too",
        arguments: languages
    )
    func notices(language: String) throws {
        try expectNoticesFit(in: language, size: CameraTextStyle.notice.size, lineCount: Self.defaultSizeLineCount)
    }

    @Test(
        "A notice at the largest text size fits the lines of its capsule in the narrowest window, under Bold Text too",
        arguments: languages
    )
    func largestNotices(language: String) throws {
        let size = CameraTextStyle.notice.size * CameraMetrics.Notice.largestTextScale
        try expectNoticesFit(in: language, size: size, lineCount: CameraMetrics.Notice.maximumLineCount)
    }

    @Test(
        "The labels of the mode switch fit their pills: whole on a phone, at their smallest scale at 320 pt",
        arguments: languages
    )
    func modeSwitch(language: String) throws {
        let ruler = TextRuler(.modeLabel, tracking: LetterTracking(language: language))
        // The widths as wide as the phone may set them, which the pills are laid out for here.
        let margin = TextRuler.platformMargin
        let widths = ModeLabelWidths(
            shooting: ruler.width(of: try catalog.capitals("flow.mode.shooting", in: language)) / margin,
            review: ruler.width(of: try catalog.capitals("flow.mode.review", in: language)) / margin
        )
        let windows = [(Self.regularPhone, 1), (Self.narrowestWindow, FlowMetrics.ModeSwitch.labelMinimumScale)]
        for (window, scale) in windows {
            let modeSwitch = ModeSwitchLayout(frame: window.layout().modeSwitch, labelWidths: widths)
            #expect(modeSwitch.segment(.shooting).width >= widths.shooting * scale + 2 * Self.gap, "\(window.name)")
            #expect(modeSwitch.segment(.review).width >= widths.review * scale + 2 * Self.gap, "\(window.name)")
        }
    }

    @Test(
        "The capsules of the drawing mode hold their labels: whole on a phone, at their smallest scale at 320 pt",
        arguments: languages
    )
    func markupCapsules(language: String) throws {
        let cancel = try catalog.text("flow.markup.cancel", in: language)
        let done = try catalog.text("flow.markup.done", in: language)
        // The widths as wide as the phone may set them, which the capsules are laid out for here.
        let margin = TextRuler.platformMargin
        let widths = MarkupLabelWidths(
            cancel: TextRuler(.markupCancel).width(of: cancel) / margin,
            done: TextRuler(.markupDone).width(of: done) / margin
        )
        let padding = 2 * FlowMetrics.MarkupTopBar.labelPadding
        let windows = [(Self.narrowPhone, 1), (Self.narrowestWindow, FlowMetrics.MarkupTopBar.labelMinimumScale)]
        for (window, scale) in windows {
            let topBar = MarkupTopBarLayout(screen: window.layout(), labelWidths: widths, isRightToLeft: false)
            #expect(topBar.cancel.width >= widths.cancel * scale + padding - 0.01, "“\(cancel)” in \(window.name)")
            #expect(topBar.done.width >= widths.done * scale + padding - 0.01, "“\(done)” in \(window.name)")
        }
    }

    @Test("The counter of the review fits between the corner buttons with a hundred photos", arguments: languages)
    func reviewCounter(language: String) throws {
        let ruler = TextRuler(.reviewCounter)
        let room = Self.narrowestWindow.layout().reviewCounter.width - 2 * Self.gap
        for text in try catalog.texts("flow.review.position", in: language) {
            expectFit(text, ruler, within: room, "counter")
        }
    }

    /// Checks that every notice of a language takes at most `lineCount` lines over the viewfinder of the narrowest
    /// window, set at `size` in the weight of a notice and in the heavier one of Bold Text.
    private func expectNoticesFit(
        in language: String,
        size: CGFloat,
        lineCount: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let row = Self.narrowestWindow.layout().notice
        let room = (row.width - 2 * CameraMetrics.Notice.horizontalPadding) * TextRuler.platformMargin
        let keys = catalog.strings.keys.filter { key in
            let isCameraNotice = key.hasPrefix("camera.notice.") && Self.failureKeys.contains(key) == false
            return isCameraNotice || key.hasPrefix("flow.notice.") || key.hasPrefix("flow.markup.notice.")
        }
        #expect(keys.count == 30, sourceLocation: sourceLocation)
        let rulers = [CameraTextStyle.notice.weight, Self.boldTextWeight].map { weight in
            TextRuler(CameraTextStyle(size: size, weight: weight))
        }
        for key in keys.sorted() {
            for text in try catalog.texts(key, in: language) {
                for ruler in rulers {
                    let lines = ruler.lineCount(of: text, within: room)
                    let comment: Comment = "\(key): “\(text)” takes \(lines) lines at \(size) pt"
                    #expect(lines <= lineCount, comment, sourceLocation: sourceLocation)
                }
            }
        }
    }
}
#endif
