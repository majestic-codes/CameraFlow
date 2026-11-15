//
//  PhotoLibrarySavingModelTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@MainActor
@Suite(
    "Saving to the photo library: the access it asks for and the refusal it keeps",
    .temporaryDirectory,
    .timeLimit(.minutes(1))
)
struct PhotoLibrarySavingModelTests {

    private func makeEntry(named name: String) throws -> PhotoLibraryEntry {
        let photoURL = TestDirectory.current.appendingPathComponent(name)
        try Data([1]).write(to: photoURL)
        return PhotoLibraryEntry(photoFileURL: photoURL, livePhotoMovieURL: nil, markedUpFileURL: nil)
    }

    @Test("A switch the library refuses stays off and keeps why, until the refusal is cleared")
    func refusedSwitch() async {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false, writer: writer)
        let refusal = await saving.setOn(true)
        #expect(refusal == .accessDenied)
        #expect(saving.isOn == false)
        #expect(saving.refusal == .accessDenied)
        saving.clearRefusal()
        #expect(saving.refusal == nil)
    }

    @Test("An album over limited access keeps the limited refusal")
    func limitedAlbum() async {
        let writer = FakePhotoLibraryWriter(authorization: .limited)
        let album = CameraFlowPhotoLibrarySaving.Destination.album(named: "Field")
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false, destination: album, writer: writer)
        await saving.setOn(true)
        #expect(saving.refusal == .limitedAccess)
        #expect(saving.isOn == false)
    }

    @Test("A request ahead of the first save that the library refuses keeps why", arguments: [true, false])
    func refusedRequest(isUserAdjustable: Bool) async {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .restricted)
        let saving = CaptureTestSupport.makeLibrarySaving(isUserAdjustable: isUserAdjustable, writer: writer)
        let refusal = await saving.requestAccess()
        #expect(refusal == .accessRestricted)
        #expect(saving.refusal == .accessRestricted)
        #expect(saving.isOn == !isUserAdjustable)
    }

    @Test("A granted switch, a switch off and a granted request keep no refusal")
    func granted() async {
        let saving = CaptureTestSupport.makeLibrarySaving(isOn: false)
        await saving.setOn(true)
        #expect(saving.refusal == nil)
        let refusal = await saving.requestAccess()
        #expect(refusal == nil)
        await saving.setOn(false)
        #expect(saving.refusal == nil)
        #expect(saving.isOn == false)
    }

    @Test("A save the library refuses is the set's to tell, and keeps no refusal here")
    func refusedSave() async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .denied)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let save = await saving.save(try makeEntry(named: "photo.jpg"))
        #expect(save == .failed(.accessDenied))
        #expect(saving.refusal == nil)
        #expect(writer.additions.isEmpty)
    }

    @Test("A request the system leaves undecided is a refusal, and nothing is saved")
    func undecidedAnswer() async throws {
        let writer = FakePhotoLibraryWriter(grantedOnRequest: .notDetermined)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let save = await saving.save(try makeEntry(named: "photo.jpg"))
        #expect(save == .failed(.accessDenied))
        #expect(writer.requestedAccess == [.addOnly])
        #expect(writer.additions.isEmpty)
    }

    @Test("A save that comes while the first one waits for the user's answer waits for that answer too")
    func oneAccessRequestForTwoSaves() async throws {
        let gate = CallGate()
        let writer = FakePhotoLibraryWriter(authorizationGate: gate)
        let saving = CaptureTestSupport.makeLibrarySaving(writer: writer)
        let firstEntry = try makeEntry(named: "first.heic")
        let secondEntry = try makeEntry(named: "second.heic")
        let first = Task { await saving.save(firstEntry) }
        await gate.arrival()
        let second = Task { await saving.save(secondEntry) }
        await settleQueuedWork()
        #expect(writer.requestedAccess == [.addOnly])
        await gate.open()
        let saves = [await first.value, await second.value]
        #expect(writer.requestedAccess == [.addOnly])
        let identifiers = saves.compactMap { save -> String? in
            guard case let .saved(asset) = save else { return nil }
            return asset.localIdentifier
        }
        #expect(identifiers.sorted() == ["asset-1", "asset-2"])
        let saved = Set(writer.additions.map(\.entry.photoFileURL))
        #expect(saved == [firstEntry.photoFileURL, secondEntry.photoFileURL])
    }
}
