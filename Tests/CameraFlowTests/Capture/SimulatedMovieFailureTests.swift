//
//  SimulatedMovieFailureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The simulated camera's failure to write its Live Photo movie, which a log shows whole as the camera's own error.
@MainActor
@Suite("The simulated Live Photo movie that cannot be written", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SimulatedMovieFailureTests {

    @Test("The capture fails with the movie named by its file, never with the folders it was to go into")
    func movieWriteFailure() async throws {
        let parent = TestDirectory.current
        let movies = try CaptureFileStore.temporaryMovieURL(parent: parent).deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: movies.path)
        defer {
            do {
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: movies.path)
            } catch {
                Issue.record(error, "The directory of the movies cannot be made writable again")
            }
        }
        let service = SimulatedCameraService(scene: .black)
        service.temporaryDirectory = parent
        _ = try await service.start(position: .back)
        let capabilities = try #require(service.photoCapabilities)
        let resolution = try #require(capabilities.resolution)
        let request = try PhotoCaptureRequest(
            flashMode: .off,
            isLivePhotoEnabled: true,
            format: .heif,
            resolution: resolution,
            capabilities: capabilities
        )
        let error = await #expect(throws: CameraServiceError.self) {
            _ = try await service.capturePhoto(request)
        }
        guard case let .captureFailed(text) = try #require(error) else {
            Issue.record("The capture failed with \(String(describing: error)) instead")
            return
        }
        #expect(text.hasPrefix("Cannot write the simulated Live Photo movie: "))
        #expect(text.contains(".mov"))
        #expect(text.contains(parent.path) == false)
        let logged = LoggedReason(try #require(error))
        #expect(logged.details.isEmpty)
        #expect(logged.summary.contains(parent.path) == false)
    }
}
