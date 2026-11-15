//
//  OnboardingSymbolTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Symbols of the introduction")
struct OnboardingSymbolTests {

    @Test("The review and the saving show the symbols of the Markup button and of the Save indicator")
    func sharedSymbols() {
        #expect(OnboardingSymbol.review.systemName == FlowSymbol.markup.rawValue)
        #expect(OnboardingSymbol.librarySave.systemName == FlowSymbol.librarySave.rawValue)
    }

    @Test("Every step's symbol has a name of its own")
    func distinctNames() {
        let names = OnboardingSymbol.allCases.map(\.systemName)
        #expect(Set(names).count == names.count)
    }
}
