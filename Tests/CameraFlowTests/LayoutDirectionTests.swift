//
//  LayoutDirectionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@testable import CameraFlow

/// A right-to-left language: the controls of the camera stay where the layout puts them, in screen coordinates, the
/// review and the drawing mirror theirs in their layouts, and the introduction and the alerts mirror with the
/// language.
@Suite("Right-to-left languages")
struct LayoutDirectionTests {
    private static let pin = #"\.layoutDirection, .leftToRight"#
    private static let flowScreen = "Views/Flow/CameraFlowScreen.swift"
    private static let languageEnvironment = "Views/Components/FlowLocalizationEnvironment.swift"

    private let tree: SourceTree

    init() throws {
        tree = try SourceTree.checkout()
    }

    private func code(of path: String) throws -> String {
        let file = try #require(tree.files.first { $0.path == path }, "\(path)")
        return file.code.joined(separator: "\n")
    }

    @Test("The flow screen pins its controls left to right, once, on the container that places them")
    func flowScreenIsPinned() throws {
        let code = try code(of: Self.flowScreen)
        #expect(code.ranges(of: Self.pin).count == 1)
        let container = try #require(code.firstRange(of: "alignment: .topLeading)\n"))
        let pin = try #require(code.firstRange(of: Self.pin))
        let overlay = try #require(code.firstRange(of: "OnboardingLayer("))
        #expect(container.upperBound < pin.lowerBound)
        #expect(pin.upperBound < overlay.lowerBound)
    }

    @Test("Only the language of the flow sets a layout direction besides the pin, so the introduction mirrors with it")
    func nothingElseIsPinned() {
        let others = tree.files.filter { file in
            file.path != Self.flowScreen && file.code.contains { $0.contains("layoutDirection") }
        }
        #expect(others.map(\.path) == [Self.languageEnvironment])
    }

    @Test("The language of the flow sets the direction of its texts only when the app names a language")
    func languageSetsDirection() {
        #expect(FlowLocalization(.specific(Locale.Language(identifier: "ar"))).isRightToLeft)
        #expect(FlowLocalization(.specific(Locale.Language(identifier: "he"))).isRightToLeft)
        #expect(FlowLocalization(.specific(Locale.Language(identifier: "uk"))).isRightToLeft == false)
        #expect(FlowLocalization.system.isSystem)
        #expect(FlowLocalization(.specific(Locale.Language(identifier: "en"))).isSystem == false)
    }

    @Test(
        "With the labels of a right-to-left language the shooting pill is still the left one",
        arguments: ["ar", "he"]
    )
    func modeSwitchKeepsItsOrder(language: String) throws {
        let catalog = try StringCatalog.checkout()
        let ruler = TextRuler(.modeLabel, tracking: LetterTracking(language: language))
        let widths = ModeLabelWidths(
            shooting: ruler.width(of: try catalog.text("flow.mode.shooting", in: language)),
            review: ruler.width(of: try catalog.text("flow.mode.review", in: language))
        )
        let screen = LayoutWindow.referencePhone.layout(panelTileCount: 5)
        let modeSwitch = ModeSwitchLayout(frame: screen.modeSwitch, labelWidths: widths)
        let shooting = modeSwitch.segment(.shooting)
        let review = modeSwitch.segment(.review)
        #expect(shooting.minX < review.minX)
        #expect(shooting.maxX == review.minX)
        #expect(modeSwitch.travel > 0)
        #expect(modeSwitch.insideCapsule.mode(atOffset: 1) == .shooting)
        #expect(modeSwitch.badge.midX > review.midX)
        #expect(screen.exit.maxX < shooting.minX)
        #expect(screen.accept.minX > review.maxX)
    }
}
#endif
