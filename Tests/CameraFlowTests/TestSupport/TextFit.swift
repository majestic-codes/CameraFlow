//
//  TextFit.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreGraphics
import Foundation
import Testing

extension StringCatalog {

    /// The texts of a key in a language, one for each plural form, with numbers in the place of the arguments.
    func texts(_ key: String, in language: String, number: String = "100") throws -> [String] {
        let localization = try #require(strings[key]?.localizations[language], "\(key) in \(language)")
        return localization.texts.values.map { text in
            text.replacing(#/%(?:\d+\$)?lld/#, with: number).replacing(#/%(?:\d+\$)?@/#, with: "88,8 MB")
        }
    }

    /// The text of a key as the code shows it in capitals.
    func capitals(_ key: String, in language: String) throws -> String {
        try text(key, in: language).uppercased(with: Locale(identifier: language))
    }
}

/// Checks that a text fits a room as wide as the phone may set it: the ruler's width, set at a scale where the view
/// lets the text shrink, within the share of the room that leaves the phone its few percent.
func expectFit(
    _ text: String,
    _ ruler: TextRuler,
    within room: CGFloat,
    scale: CGFloat = 1,
    _ place: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let width = ruler.width(of: text) * scale
    let comment: Comment = "\(place): “\(text)” is \(width) pt wide in \(room) pt"
    #expect(width <= room * TextRuler.platformMargin, comment, sourceLocation: sourceLocation)
}
#endif
