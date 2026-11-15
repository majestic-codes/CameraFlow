//
//  CameraFlowPhotoLibrarySavingSwitchTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Saving to the photo library: the user's switch", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowPhotoLibrarySavingSwitchTests {

    @Test("Switching saving on asks for access there and then, and a refusal leaves it off with a notice")
    func switchingOn() async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let (_, flow) = makeSavingFlow(writer: writer, isOn: false)
        let settings = flow.camera.settings
        #expect(settings.isLibrarySavingOn == false)
        #expect(settings.offeredSettings.contains(.librarySave))
        #expect(settings.topBarSettings == [.flash, .live, .librarySave])
        await settings.toggleLibrarySaving()
        #expect(writer.requestedAccess == [.addOnly])
        #expect(settings.isLibrarySavingOn == false)
        #expect(flow.camera.librarySaving?.refusal == .accessDenied)
        #expect(FlowText(.system).notice(for: flow) == "Photo library access is denied in Settings")
        await settings.toggleLibrarySaving()
        #expect(settings.isLibrarySavingOn == false)
        flow.photoSet.discard()
    }

    @Test("The notice of a refused switch goes with the next thing the user does, like any other")
    func refusedSwitchNoticeIsTransient() async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let (_, flow) = makeSavingFlow(writer: writer, isOn: false)
        await flow.camera.start()
        await flow.camera.settings.toggleLibrarySaving()
        #expect(FlowText(.system).notice(for: flow) == "Photo library access is denied in Settings")
        flow.camera.settings.cycleFlash()
        #expect(FlowText(.system).notice(for: flow) == nil)
        await flow.camera.settings.toggleLibrarySaving()
        #expect(FlowText(.system).notice(for: flow) == "Photo library access is denied in Settings")
        await flow.camera.capture()
        #expect(FlowText(.system).notice(for: flow) == nil)
        flow.photoSet.discard()
    }

    @Test("The notice of a refused switch does not hide what the set says later")
    func refusedSwitchNoticeDoesNotMaskTheSet() async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let (_, flow) = makeSavingFlow(writer: writer, isOn: false)
        await flow.camera.start()
        await flow.camera.settings.toggleLibrarySaving()
        await flow.importPicks([FakeLibraryPick(data: nil), FakeLibraryPick(data: nil)])
        #expect(FlowText(.system).notice(for: flow) == "2 photos could not be loaded")
        flow.photoSet.discard()
    }

    @Test("Switching saving on with access granted turns it on, and off again takes no access")
    func switchingOnAndOff() async throws {
        let writer = FakePhotoLibraryWriter()
        let (_, flow) = makeSavingFlow(writer: writer, isOn: false)
        let settings = flow.camera.settings
        await settings.toggleLibrarySaving()
        #expect(settings.isLibrarySavingOn)
        #expect(writer.requestedAccess == [.addOnly])
        await settings.select(isLibrarySavingEnabled: false)
        #expect(settings.isLibrarySavingOn == false)
        let saving = try #require(flow.camera.librarySaving)
        #expect(saving.refusal == nil)
        flow.photoSet.discard()
    }

    @Test("A fixed switch is neither shown nor moved")
    func fixedSwitch() async {
        let writer = FakePhotoLibraryWriter()
        let (_, flow) = makeSavingFlow(writer: writer, isOn: true, isUserAdjustable: false)
        let settings = flow.camera.settings
        #expect(settings.offeredSettings.contains(.librarySave) == false)
        #expect(settings.topBarSettings == [.flash, .live])
        await settings.toggleLibrarySaving()
        #expect(settings.isLibrarySavingOn)
        flow.photoSet.discard()
    }

    @Test("A flow that never saves has no saving model and no Save control")
    func neverSaves() async {
        let harness = FlowHarness(service: RecordingCameraService())
        let flow = harness.makeFlow()
        await flow.camera.start()
        #expect(flow.camera.settings.librarySaving == nil)
        #expect(flow.camera.settings.deliversPhotos(within: flow.camera.settings.output))
        #expect(flow.camera.settings.topBarSettings == [.flash, .live])
        flow.photoSet.discard()
    }
}
