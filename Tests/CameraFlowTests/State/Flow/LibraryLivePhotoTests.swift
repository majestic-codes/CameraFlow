//
//  LibraryLivePhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A Live Photo picked from the library reaches the app with its movie, as one taken with the camera does.
@MainActor
@Suite("A Live Photo picked from the library", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LibraryLivePhotoTests {
    let files = CaptureTestSupport.makeFileStore()
    private let movie = Data("movie".utf8)

    @Test("A picked Live Photo is handed over with its movie")
    func handedOverWithMovie() async throws {
        var handedOver: [CameraFlowPhoto] = []
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: RecordingMarkupRenderer()) {
            handedOver = $0
        }
        await photoSet.importPicks([FakeLibraryPick(data: try DevicePhotoFixture.make(), movieData: movie)])
        await photoSet.handOver()
        let photo = try #require(handedOver.first)
        #expect(photo.source == .photoLibrary)
        let movieURL = try #require(photo.livePhotoMovieURL)
        #expect(try Data(contentsOf: movieURL) == movie)
        #expect(movieURL.deletingLastPathComponent() == photo.original.url.deletingLastPathComponent())
    }

    @Test("A picked Live Photo removed from the set takes its movie with it")
    func removedWithMovie() async throws {
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: RecordingMarkupRenderer()) { _ in
            Issue.record("Nothing is handed over")
        }
        await photoSet.importPicks([FakeLibraryPick(data: try DevicePhotoFixture.make(), movieData: movie)])
        let photo = try #require(photoSet.photos.first)
        let movieURL = try #require(photo.livePhotoMovieURL)
        photoSet.remove(photo)
        #expect(FileManager.default.fileExists(atPath: movieURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: photo.fileURL.path) == false)
    }

    @Test("A picked Live Photo that arrives after the set was discarded is deleted with its movie")
    func arrivesAfterDiscard() async throws {
        let photoSet = PhotoSetModel(limit: .unlimited, fileStore: files, renderer: RecordingMarkupRenderer()) { _ in
            Issue.record("Nothing is handed over")
        }
        let gate = CallGate()
        let pick = FakeLibraryPick(data: try DevicePhotoFixture.make(), movieData: movie, gate: gate)
        let importing = Task { await photoSet.importPicks([pick]) }
        await gate.arrival()
        photoSet.discard()
        await gate.open()
        await importing.value
        #expect(photoSet.photos.isEmpty)
        let stored = FileManager.default.fileExists(atPath: files.directory.path)
            ? try FileManager.default.contentsOfDirectory(atPath: files.directory.path)
            : []
        #expect(stored.isEmpty)
    }
}
