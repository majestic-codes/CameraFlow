//
//  SystemSymbolTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import AppKit
import Testing
@testable import CameraFlow

/// The system symbols the flow draws by name: a misspelled name draws nothing, and nothing else would notice.
@Suite("System symbols")
struct SystemSymbolTests {
    /// Every name the camera glyphs, the flow and the introduction draw, the viewfinder of the aspect ratios included.
    static let names: [String] = {
        let cameraNames = CameraGlyph.allCases.compactMap { glyph -> String? in
            switch glyph.artwork {
            case let .symbol(name), let .badgedSymbol(name): name
            case .aspectRatio: CameraGlyph.viewfinderSymbol
            case .timer, .controlDots: nil
            }
        }
        let flowNames = FlowSymbol.allCases.map(\.rawValue)
        let onboardingNames = OnboardingSymbol.allCases.map(\.systemName)
        return Array(Set(cameraNames + flowNames + onboardingNames)).sorted()
    }()

    @Test("Every system symbol the flow draws exists", arguments: names)
    func symbolExists(name: String) {
        // NSImage is the only way to look a symbol up by its name on the macOS test host.
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }

    @Test("A misspelled name is caught")
    func misspelledName() {
        #expect(NSImage(systemSymbolName: "pencil.tip.crop.circlee", accessibilityDescription: nil) == nil)
    }
}
#endif
