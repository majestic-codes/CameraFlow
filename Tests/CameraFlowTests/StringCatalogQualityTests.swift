//
//  StringCatalogQualityTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import Foundation
import Testing

/// The texts of the quality the camera writes and VoiceOver reads, and the stock title of the lens picker, where a
/// translation was cut short or took another word than the system's.
@Suite("The quality texts and the lens picker title")
struct StringCatalogQualityTests {
    private let catalog: StringCatalog

    init() throws {
        catalog = try StringCatalog.checkout()
    }

    @Test(
        "A quality mark that is not three capitals is a whole word for the quality, never a part of one",
        arguments: [
            ("ar", "وسط", "أدنى"), ("he", "בינוני", "נמוך"), ("hi", "मध्यम", "निम्न"), ("ko", "중간", "낮음"),
            ("th", "กลาง", "ต่ำ"), ("vi", "VỪA", "THẤP"), ("ja", "中", "低"), ("zh-Hans", "中", "低"),
            ("zh-Hant", "中", "低")
        ]
    )
    func wholeWords(language: String, medium: String, low: String) throws {
        #expect(try catalog.text("camera.quality.medium.mark", in: language) == medium)
        #expect(try catalog.text("camera.quality.low.mark", in: language) == low)
    }

    @Test(
        "VoiceOver reads a quality in the system's whole word, where the option shows a shorter one",
        arguments: [
            ("et", "medium", "Keskm.", "Keskmine"), ("fi", "medium", "Keski", "Keskitaso"),
            ("nl", "medium", "Midden", "Gemiddeld"), ("vi", "medium", "Vừa", "Trung bình"),
            ("hu", "low", "Gyenge", "Alacsony")
        ]
    )
    func spokenQualities(language: String, quality: String, written: String, spoken: String) throws {
        #expect(try catalog.text("camera.quality.\(quality)", in: language) == written)
        #expect(try catalog.text("camera.quality.\(quality).accessibility", in: language) == spoken)
    }

    @Test("The lens picker of the Camera Control is titled as the system Camera titles it in Hindi")
    func lensPickerTitle() throws {
        #expect(try catalog.text("camera.captureControl.lenses", in: "hi") == "कैमरा")
    }
}
#endif
