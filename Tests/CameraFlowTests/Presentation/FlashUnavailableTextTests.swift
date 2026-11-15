//
//  FlashUnavailableTextTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("What the screen says of a flash that cannot fire, in the stock camera's words")
struct FlashUnavailableTextTests {
    /// A reason the flash cannot fire, the device it is said on, and the text.
    struct MessageCase: Sendable, CustomTestStringConvertible {
        let reason: FlashUnavailability
        let device: DeviceFamily
        let text: String

        var testDescription: String {
            "\(reason) on \(device)"
        }
    }

    @Test("The alert has the stock title and button")
    func titleAndButton() {
        #expect(FlashUnavailableText(.system).title == "Flash is Disabled")
        #expect(FlashUnavailableText(.system).dismiss == "OK")
    }

    @Test(
        "The message names the device and says whether it has to cool down or to be charged",
        arguments: [
            MessageCase(reason: .heat, device: .phone, text: "iPhone needs to cool down before you can use the flash."),
            MessageCase(reason: .heat, device: .pad, text: "iPad needs to cool down before you can use the flash."),
            MessageCase(
                reason: .power,
                device: .phone,
                text: "iPhone battery is low and needs to be charged before you can use the flash."
            ),
            MessageCase(
                reason: .power,
                device: .pad,
                text: "iPad battery is low and needs to be charged before you can use the flash."
            )
        ]
    )
    func message(messageCase: MessageCase) {
        let message = FlashUnavailableText(.system).message(for: messageCase.reason, on: messageCase.device)
        #expect(message == messageCase.text)
    }

    @Test("The texts follow the language of the flow, with the device named as the stock camera names it there")
    func language() {
        let ukrainian = FlashUnavailableText(FlowLocalization(.specific(Locale.Language(identifier: "uk"))))
        #expect(ukrainian.title == "Спалах вимкнено")
        #expect(ukrainian.message(for: .heat, on: .pad) == "iPad повинен охолонути, перш ніж використовувати спалах.")
        let polish = FlashUnavailableText(FlowLocalization(.specific(Locale.Language(identifier: "pl"))))
        let polishMessage = "Aby użyć lampy błyskowej, musisz schłodzić iPhone’a."
        #expect(polish.message(for: .heat, on: .phone) == polishMessage)
    }
}
