//
//  LibrarySettingsAccessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// When the Save sub-panel offers the way to the app's page of Settings: while the library refuses the access the
/// destination needs and the user can grant it there.
@MainActor
@Suite("The way to Settings for a refused photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LibrarySettingsAccessTests {

    @Test(
        "Denied access, and limited access for an album, are lifted in Settings",
        arguments: [
            (PhotoLibraryAuthorization.denied, false, true),
            (.denied, true, true),
            (.limited, true, true),
            (.limited, false, false),
            (.restricted, false, false),
            (.restricted, true, false),
            (.authorized, true, false),
            (.notDetermined, false, false)
        ]
    )
    func liftedInSettings(authorization: PhotoLibraryAuthorization, isAlbum: Bool, isLifted: Bool) {
        let writer = FakePhotoLibraryWriter(authorization: authorization)
        let destination: CameraFlowPhotoLibrarySaving.Destination = isAlbum ? .album(named: "Field") : .library
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false, destination: destination, writer: writer)
        #expect(saving.isRefusalLiftedInSettings == isLifted)
    }

    @Test("Reading it never asks the library")
    func readsWithoutAsking() {
        let writer = FakePhotoLibraryWriter(authorization: .notDetermined)
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: true, writer: writer)
        #expect(saving.isRefusalLiftedInSettings == false)
        #expect(writer.requestedAccess.isEmpty)
    }

    @Test("A switch the user just refused offers the way to Settings")
    func afterRefusal() async {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false, writer: writer)
        #expect(saving.isRefusalLiftedInSettings == false)
        await saving.setOn(true)
        #expect(saving.isRefusalLiftedInSettings)
    }
}
