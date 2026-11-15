//
//  FlashUnavailableText.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// What the screen says of a flash that cannot fire for a while, in the stock camera's words: the alert a tap on the
/// Flash indicator shows, which VoiceOver reads on the indicator too.
struct FlashUnavailableText {
    let localization: FlowLocalization

    init(_ localization: FlowLocalization) {
        self.localization = localization
    }

    /// The title of the alert, and the value of the Flash indicator meanwhile.
    var title: String {
        String(
            localized: "camera.flashDisabled.title",
            defaultValue: "Flash is Disabled",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    /// Why the flash cannot fire, named after the device: the message of the alert, and the hint of the Flash
    /// indicator meanwhile.
    func message(for reason: FlashUnavailability, on device: DeviceFamily) -> String {
        switch reason {
        case .heat: coolingMessage(on: device)
        case .power: chargingMessage(on: device)
        }
    }

    /// The button that closes the alert.
    var dismiss: String {
        String(
            localized: "camera.flashDisabled.ok",
            defaultValue: "OK",
            bundle: localization.bundle,
            locale: localization.locale
        )
    }

    private func coolingMessage(on device: DeviceFamily) -> String {
        switch device {
        case .phone:
            String(
                localized: "camera.flashDisabled.heat.iPhone",
                defaultValue: "iPhone needs to cool down before you can use the flash.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .pad:
            String(
                localized: "camera.flashDisabled.heat.iPad",
                defaultValue: "iPad needs to cool down before you can use the flash.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }

    private func chargingMessage(on device: DeviceFamily) -> String {
        switch device {
        case .phone:
            String(
                localized: "camera.flashDisabled.power.iPhone",
                defaultValue: "iPhone battery is low and needs to be charged before you can use the flash.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        case .pad:
            String(
                localized: "camera.flashDisabled.power.iPad",
                defaultValue: "iPad battery is low and needs to be charged before you can use the flash.",
                bundle: localization.bundle,
                locale: localization.locale
            )
        }
    }
}
