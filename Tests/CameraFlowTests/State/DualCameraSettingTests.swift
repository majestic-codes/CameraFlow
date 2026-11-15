//
//  DualCameraSettingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Dual camera: the circle as a setting of the flow", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraSettingTests {
    private let store = FakePreferenceStore()

    /// The circle as the app set it, on a device that can run two cameras or not.
    struct SettingCase: Sendable, CustomTestStringConvertible {
        let name: String
        let setting: CameraFlowSetting<Bool>
        let isSupported: Bool
        let hasControl: Bool
        let opensOn: Bool

        var testDescription: String {
            name
        }
    }

    nonisolated static let settingCases = [
        SettingCase(
            name: "adjustable",
            setting: CameraFlowSetting(false),
            isSupported: true,
            hasControl: true,
            opensOn: false
        ),
        SettingCase(
            name: "adjustable, on",
            setting: CameraFlowSetting(true),
            isSupported: true,
            hasControl: true,
            opensOn: true
        ),
        SettingCase(
            name: "a device without two cameras",
            setting: CameraFlowSetting(true),
            isSupported: false,
            hasControl: false,
            opensOn: false
        ),
        SettingCase(name: "fixed on", setting: .fixed(true), isSupported: true, hasControl: false, opensOn: true),
        SettingCase(name: "fixed off", setting: .fixed(false), isSupported: true, hasControl: false, opensOn: false)
    ]

    private func makeModel(
        setting: CameraFlowSetting<Bool> = CameraFlowSetting(false),
        service: RecordingCameraService = RecordingCameraService(),
        librarySaving: PhotoLibrarySavingModel? = nil,
        onPreferencesChange: ((CameraFlowPreferences) -> Void)? = nil
    ) -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        state.isDualCameraEnabled = setting
        let model = makeCaptureModel(
            service: service,
            initialState: state,
            isDualCameraOffered: true,
            memory: CaptureTestSupport.makeMemory(store: store),
            librarySaving: librarySaving,
            onPreferencesChange: onPreferencesChange
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    private var rememberedSettings: CameraFlowPreferences {
        CaptureTestSupport.makeMemory(store: store).load()
    }

    @Test(
        "The circle has its indicator and tile only while the user may switch it on a device that has it",
        arguments: settingCases
    )
    func control(settingCase: SettingCase) async {
        let service = RecordingCameraService(isDualCameraSupported: settingCase.isSupported)
        let model = makeModel(setting: settingCase.setting, service: service)
        await model.start()
        #expect(model.settings.topBarSettings.contains(.dualCamera) == settingCase.hasControl)
        #expect(model.settings.offeredSettings.contains(.dualCamera) == settingCase.hasControl)
        #expect(model.panel.settings.contains(.dualCamera) == settingCase.hasControl)
        #expect(model.dualCamera.isOn == settingCase.opensOn)
        #expect(model.notices.dualCameraNotice == nil)
    }

    @Test("A circle the app fixed takes no toggle", arguments: [true, false])
    func fixedTakesNoToggle(isOn: Bool) async {
        let model = makeModel(setting: .fixed(isOn))
        await model.start()
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn == isOn)
        #expect(rememberedSettings.isDualCameraEnabled == nil)
    }

    @Test("The top bar puts the circle after Flash and Live and before Save")
    func topBarOrder() async {
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false)
        let model = makeModel(librarySaving: saving)
        #expect(model.settings.topBarSettings == [.flash, .live, .dualCamera, .librarySave])
        #expect(model.settings.offeredSettings.suffix(2) == [.dualCamera, .librarySave])
    }

    @Test("A switch the user made is remembered and reported to the app, and the next flow opens with it")
    func remembered() async {
        var reported: [CameraFlowPreferences] = []
        let first = makeModel { reported.append($0) }
        await first.start()
        await first.toggleDualCamera()
        #expect(rememberedSettings.isDualCameraEnabled == true)
        let second = makeModel()
        await second.start()
        #expect(second.dualCamera.isOn)
        await second.toggleDualCamera()
        #expect(rememberedSettings.isDualCameraEnabled == false)
        #expect(makeModel().settings.opensWithDualCamera == false)
        #expect(reported.map(\.isDualCameraEnabled) == [true])
    }

    @Test("A circle remembered on opens off on a device without it, and stays remembered on")
    func rememberedOnWithoutDevice() async {
        let first = makeModel()
        await first.start()
        await first.toggleDualCamera()
        let service = RecordingCameraService(isDualCameraSupported: false)
        let second = makeModel(service: service)
        await second.start()
        #expect(second.dualCamera.isOn == false)
        #expect(service.calls.contains(.startDualCamera(main: .back)) == false)
        second.settings.cycleFlash()
        #expect(rememberedSettings.isDualCameraEnabled == true)
        #expect(rememberedSettings.flashMode == .alwaysOn)
    }

    @Test("A circle that failed to come on, or that the device turned off, is not remembered off")
    func flowChangesNotRemembered() async {
        let first = makeModel()
        await first.start()
        await first.toggleDualCamera()
        let failing = RecordingCameraService()
        failing.dualStartError = .cannotUseCamera("The camera is in use")
        let second = makeModel(service: failing)
        await second.start()
        #expect(second.dualCamera.isOn == false)
        #expect(rememberedSettings.isDualCameraEnabled == true)
        let service = RecordingCameraService()
        let third = makeModel(service: service)
        await third.start()
        await service.simulate(.dualCameraPressureCritical)
        await settle { third.dualCamera.isOn == false }
        #expect(rememberedSettings.isDualCameraEnabled == true)
    }

    @Test("A pair that delivers less than the 12 MP in effect leaves them out once and says why")
    func smallerSizeOfThePair() async {
        let service = RecordingCameraService(dualPhotoCapabilities: CaptureTestSupport.dualWithSmallerSize)
        let model = makeModel(service: service)
        await model.start()
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
        await model.toggleDualCamera()
        #expect(model.notices.dualCameraNotice == .settingOff(.resolution))
        #expect(model.settings.effectivePhotoFrame?.isPreferred == false)
        #expect(model.settings.effectivePhotoFrame?.megapixels == 8)
        await model.flipCamera()
        #expect(model.notices.dualCameraNotice == nil)
        await model.toggleDualCamera()
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
    }

    @Test("A flow that opens with the circle on says nothing about what one camera alone would take")
    func opensWithoutNotice() async {
        let service = RecordingCameraService(dualPhotoCapabilities: CaptureTestSupport.dualWithSmallerSize)
        let model = makeModel(setting: CameraFlowSetting(true), service: service)
        await model.start()
        #expect(model.dualCamera.isOn)
        #expect(model.notices.dualCameraNotice == nil)
    }
}
