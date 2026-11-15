//
//  SimulatedPhotoLibraryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Simulated photo library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SimulatedPhotoLibraryTests {

    @Test("The simulated photo library is granted from the start, or when it is asked for, and takes photos")
    func simulatedLibrary() async throws {
        let grantedLibrary = SimulatedPhotoLibrary(isAuthorizationDetermined: true)
        #expect(grantedLibrary.authorizationStatus(for: .addOnly) == .authorized)
        let library = SimulatedPhotoLibrary(isAuthorizationDetermined: false)
        #expect(library.authorizationStatus(for: .readWrite) == .notDetermined)
        #expect(await library.requestAuthorization(for: .readWrite) == .authorized)
        #expect(library.authorizationStatus(for: .readWrite) == .authorized)
        let photoFileURL = TestDirectory.current.appendingPathComponent("photo.heic")
        let entry = PhotoLibraryEntry(photoFileURL: photoFileURL, livePhotoMovieURL: nil, markedUpFileURL: nil)
        let first = try await library.add(entry, toAlbumNamed: nil)
        let second = try await library.add(entry, toAlbumNamed: "Album")
        #expect(first == CameraFlowPhotoLibraryAsset(localIdentifier: "simulated-asset-1"))
        #expect(second == CameraFlowPhotoLibraryAsset(localIdentifier: "simulated-asset-2"))
    }
}
