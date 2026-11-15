//
//  CameraSettingSpeechTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// What accessibility reads for the settings: in full where the panel writes short forms.
@MainActor
@Suite("Spoken setting text", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraSettingSpeechTests {

    private static func speech(_ language: String) -> CameraSettingSpeech {
        CameraSettingSpeech(FlowLocalization(.specific(Locale.Language(identifier: language))))
    }

    @Test(
        "A setting is named in full where its tile is short",
        arguments: [
            (CameraSetting.flash, "Flash"),
            (.live, "Live Photo"),
            (.aspect, "Aspect ratio"),
            (.timer, "Timer"),
            (.exposure, "Exposure"),
            (.format, "Photo format"),
            (.dualCamera, "Dual Capture"),
            (.librarySave, "Save")
        ]
    )
    func names(setting: CameraSetting, name: String) {
        #expect(CameraSettingSpeech(.system).name(of: setting) == name)
    }

    @Test(
        "The options read in full",
        arguments: [
            (CameraFlowAspectRatio.fourByThree, "4 by 3"),
            (.sixteenByNine, "16 by 9"),
            (.square, "Square")
        ]
    )
    func aspectRatios(ratio: CameraFlowAspectRatio, spoken: String) {
        #expect(CameraSettingSpeech(.system).aspectRatio(ratio) == spoken)
    }

    @Test("Flash modes, switches, delays and qualities read in full")
    func options() {
        let speech = CameraSettingSpeech(.system)
        #expect(speech.flashMode(.auto) == "Automatic")
        #expect(speech.flashMode(.alwaysOn) == "On")
        #expect(speech.flashMode(.off) == "Off")
        #expect(speech.timer(.off) == "Off")
        #expect(speech.timer(.threeSeconds) == "3 seconds")
        #expect(speech.timer(.tenSeconds) == "10 seconds")
        #expect(speech.quality(.medium) == "Medium")
    }

    @Test(
        "Where a language shortens the visible text, VoiceOver reads the whole word",
        arguments: [
            ("ru", "Вкл.", "Включено"),
            ("pl", "Wł.", "Włączone"),
            ("sk", "Zap.", "Zapnuté")
        ]
    )
    func spokenSwitch(language: String, visible: String, spoken: String) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
        #expect(CameraSettingText(localization).switchState(isOn: true) == visible)
        #expect(CameraSettingSpeech(localization).switchState(isOn: true) == spoken)
    }

    @Test("A short tile word, a short quality and a short timer name have whole spoken forms")
    func shortForms() {
        #expect(Self.speech("el").name(of: .timer) == "Χρονοδιακόπτης")
        #expect(Self.speech("et").quality(.medium) == "Keskmine")
        #expect(Self.speech("de").name(of: .aspect) == "Seitenverhältnis")
    }

    #if os(macOS)
    @Test(
        "Voice Control answers to the word under a tile in every language, besides the name",
        arguments: StringCatalog.languages
    )
    func tileInputLabels(language: String) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: language)))
        for setting in CameraSetting.allCases {
            let labels = CameraSettingSpeech(localization).tileInputLabels(of: setting)
            let word = CameraSettingText(localization).tileName(of: setting)
            #expect(labels.contains(word), "\(language) \(setting): \(labels) lack \(word)")
            #expect(labels.contains(CameraSettingSpeech(localization).name(of: setting)))
        }
    }
    #endif

    @Test("The tile of the second camera answers to its short word and to its full name")
    func dualCameraInputLabels() {
        #expect(CameraSettingSpeech(.system).tileInputLabels(of: .dualCamera) == ["Dual", "Dual Capture"])
        #expect(CameraSettingSpeech(.system).tileInputLabels(of: .flash) == ["Flash"])
    }

    @Test("The indicator of a changed setting answers to what it writes, besides its name")
    func indicatorInputLabels() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        model.settings.select(photoFormat: .raw)
        model.settings.setExposureBias(0.7)
        let speech = CameraSettingSpeech(.system)
        let stops = CameraSettingText(.system).signedStops(0.7)
        #expect(speech.indicatorInputLabels(of: .format, in: model.settings) == ["RAW", "Photo format"])
        #expect(speech.indicatorInputLabels(of: .exposure, in: model.settings) == [stops, "Exposure"])
        #expect(speech.indicatorInputLabels(of: .aspect, in: model.settings) == ["Aspect ratio"])
    }

    @Test("The timer reads its delay in words and the aspect ratio in words")
    func values() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        model.settings.select(timer: .tenSeconds)
        model.settings.select(aspectRatio: .sixteenByNine)
        let speech = CameraSettingSpeech(.system)
        #expect(speech.value(of: .timer, in: model.settings) == "10 seconds")
        #expect(speech.value(of: .aspect, in: model.settings) == "16 by 9")
        #expect(speech.value(of: .flash, in: model.settings) == "Automatic")
    }

    @Test("Live Photo reads what the next photo takes: off while it cannot be taken, though the user chose it")
    func liveInEffect() async {
        let model = makeCaptureModel(service: RecordingCameraService())
        await model.start()
        model.settings.select(isLivePhotoEnabled: true)
        #expect(CameraSettingSpeech(.system).value(of: .live, in: model.settings) == "On")
        model.settings.select(aspectRatio: .square)
        #expect(model.settings.isLivePhotoEnabled)
        #expect(CameraSettingSpeech(.system).value(of: .live, in: model.settings) == "Off")
        #expect(CameraSettingText(.system).value(of: .live, in: model.settings) == "Off")
    }
}
