//
//  OnboardingPage.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What one step of the introduction shows: a symbol, a title, a few rows that say what the access is for, a line
/// about the request that follows and the Continue button that brings it.
struct OnboardingPage: Hashable {
    struct Row: Hashable, Identifiable {
        let symbol: OnboardingSymbol
        let title: String
        let detail: String

        var id: OnboardingSymbol {
            symbol
        }
    }

    let symbol: OnboardingSymbol
    let title: String
    let rows: [Row]
    let footnote: String
    let continueTitle: String
}
