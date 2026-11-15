//
//  FocusLockTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The stock AE/AF LOCK badge in the language of the flow, and VoiceOver's words for the lock, for what the camera
/// locks: the focus and the exposure, or one of the two.
@Suite("The words of AE/AF Lock")
struct FocusLockTextTests {
    /// The words of one camera's lock in English: the badge, the action without and with the lock, and the
    /// announcements as it takes and ends.
    struct Words: Sendable, CustomTestStringConvertible {
        let adjustments: LockableAdjustments
        let badge: String
        let lock: String
        let unlock: String
        let locked: String
        let unlocked: String

        var testDescription: String {
            "\(adjustments)"
        }
    }

    private func text(in language: String) -> FocusLockText {
        FocusLockText(FlowLocalization(.specific(Locale.Language(identifier: language))))
    }

    @Test(
        "The badge is the stock one of what the camera locks, which VoiceOver names in its action and announcements",
        arguments: [
            Words(
                adjustments: .focusAndExposure,
                badge: "AE/AF LOCK",
                lock: "Lock focus and exposure",
                unlock: "Unlock focus and exposure",
                locked: "Focus and exposure locked",
                unlocked: "Focus and exposure unlocked"
            ),
            Words(
                adjustments: .exposure,
                badge: "AE LOCK",
                lock: "Lock exposure",
                unlock: "Unlock exposure",
                locked: "Exposure locked",
                unlocked: "Exposure unlocked"
            ),
            Words(
                adjustments: .focus,
                badge: "AF LOCK",
                lock: "Lock focus",
                unlock: "Unlock focus",
                locked: "Focus locked",
                unlocked: "Focus unlocked"
            )
        ]
    )
    func english(words: Words) {
        let text = FocusLockText(.system)
        #expect(text.badge(for: words.adjustments) == words.badge)
        #expect(text.action(isLocked: false, of: words.adjustments) == words.lock)
        #expect(text.action(isLocked: true, of: words.adjustments) == words.unlock)
        #expect(text.announcement(isLocked: true, of: words.adjustments) == words.locked)
        #expect(text.announcement(isLocked: false, of: words.adjustments) == words.unlocked)
    }

    @Test(
        "The badge is the stock camera's in the language of the flow, as the stock one writes it",
        arguments: [
            ("de", "AE/AF-SPERRE"), ("fi", "Autom. valotus/tarkennus lukittu"), ("ja", "AE/AFロック"),
            ("nb", "EKSPONERING/FOKUS LÅST"), ("pt-PT", "BLOQUEIO AE/AF"), ("uk", "ЗАМОК AE/AF"),
            ("zh-Hans", "自动曝光/自动对焦锁定"), ("zh-Hant", "自動曝光/自動對焦鎖定")
        ]
    )
    func stockBadge(language: String, badge: String) {
        #expect(text(in: language).badge(for: .focusAndExposure) == badge)
    }

    @Test(
        "The badges of the exposure alone and of the focus alone are the stock camera's AE LOCK and AF LOCK",
        arguments: [
            ("de", "AE-SPERRE", "AF-SPERRE"), ("es-419", "BLOQUEO de AE", "BLOQUEO de AF"),
            ("fi", "Autom. valotus lukittu", "Autom. tarkennus lukittu"), ("ja", "AEロック", "AFロック"),
            ("nb", "AE-LÅS", "AUTOFOKUS LÅST"), ("ru", "ФИКСАЦИЯ экспозиции", "ФИКСАЦИЯ фокуса"),
            ("uk", "ЗАМОК AE", "ЗАМОК AF"), ("zh-Hans", "自动曝光锁定", "自动对焦锁定"),
            ("et", "AE LUKUSTUS", "AF LUKUSTUS"), ("lv", "AE BLOĶĒŠANA", "AF BLOĶĒŠANA")
        ]
    )
    func stockSingleBadges(language: String, exposure: String, focus: String) {
        #expect(text(in: language).badge(for: .exposure) == exposure)
        #expect(text(in: language).badge(for: .focus) == focus)
    }

    @Test("The Ukrainian AE LOCK writes AE in the Latin letters of the other two badges, as they look in the stock one")
    func latinLetters() {
        let badge = text(in: "uk").badge(for: .exposure)
        #expect(badge.unicodeScalars.suffix(2).map(\.value) == [0x41, 0x45])
    }

    @Test("VoiceOver's words follow the language of the flow")
    func spokenLanguage() {
        let ukrainian = text(in: "uk")
        #expect(ukrainian.action(isLocked: false, of: .focusAndExposure) == "Зафіксувати фокус і експозицію")
        #expect(ukrainian.announcement(isLocked: true, of: .focusAndExposure) == "Фокус і експозицію зафіксовано")
        #expect(ukrainian.action(isLocked: false, of: .exposure) == "Зафіксувати експозицію")
        #expect(ukrainian.announcement(isLocked: false, of: .focus) == "Фіксацію фокуса знято")
    }
}
