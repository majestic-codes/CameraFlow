//
//  CaptureControlTitleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Texts of the Camera Control")
struct CaptureControlTitleTests {
    /// A language of the flow, the title of the lens picker in it and the title of the ultra wide lens.
    struct Row: Sendable, CustomTestStringConvertible {
        let language: String
        let lensPicker: String
        let ultraWide: String

        var testDescription: String {
            language
        }
    }

    static let rows = [
        Row(language: "en", lensPicker: "Cameras", ultraWide: "0.5×"),
        Row(language: "uk", lensPicker: "Камери", ultraWide: "0,5×"),
        Row(language: "de", lensPicker: "Kameras", ultraWide: "0,5×"),
        Row(language: "ja", lensPicker: "カメラ", ultraWide: "0.5×")
    ]

    @Test("The lens picker speaks the flow's language, its numbers included", arguments: rows)
    func lensPicker(row: Row) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: row.language)))
        #expect(CaptureControlTitle.lensPicker(localization) == row.lensPicker)
        let ultraWide = CameraLens(factor: 0.5, focalLength: 13)
        #expect(CaptureControlTitle.lens(ultraWide, localization) == row.ultraWide)
    }
}
