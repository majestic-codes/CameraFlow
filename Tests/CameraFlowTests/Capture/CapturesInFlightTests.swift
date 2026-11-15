//
//  CapturesInFlightTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os
import Testing
@testable import CameraFlow

@Suite("Captures in flight", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CapturesInFlightTests {
    /// What the captures of a test ended with, in order.
    private final class Outcomes: Sendable {
        private let results = OSAllocatedUnfairLock(initialState: [Result<CapturedPhoto, any Error>]())

        var all: [Result<CapturedPhoto, any Error>] {
            results.withLock { $0 }
        }

        var errors: [CameraServiceError?] {
            all.map { result in
                guard case let .failure(error) = result else { return nil }
                return error as? CameraServiceError
            }
        }

        func add(_ result: Result<CapturedPhoto, any Error>) {
            results.withLock { $0.append(result) }
        }
    }

    private let captures = CapturesInFlight()
    private let outcomes = Outcomes()

    private func makePhoto(movieURL: URL? = nil) -> CapturedPhoto {
        CapturedPhoto(imageData: Data([1]), encoding: .heif, livePhotoMovieURL: movieURL)
    }

    private func makeMovie() throws -> URL {
        let url = TestDirectory.current.appendingPathComponent(UUID().uuidString + ".mov")
        try Data([4]).write(to: url)
        return url
    }

    @Test("A capture ends with what the camera delivers, once")
    func delivered() {
        let finish = captures.begin(outcomes.add)
        finish(.success(makePhoto()))
        finish(.failure(CameraServiceError.noImageData))
        captures.failAll()
        #expect(outcomes.all.count == 1)
        #expect(outcomes.errors == [nil])
    }

    @Test("A session that stops ends every capture in flight as not running, and only those")
    func stopped() {
        let first = captures.begin(outcomes.add)
        first(.failure(CameraServiceError.noImageData))
        _ = captures.begin(outcomes.add)
        _ = captures.begin(outcomes.add)
        captures.failAll()
        captures.failAll()
        #expect(outcomes.errors == [.noImageData, .notRunning, .notRunning])
        let next = captures.begin(outcomes.add)
        next(.success(makePhoto()))
        #expect(outcomes.all.count == 4)
    }

    @Test("What the camera delivers after its session stopped is dropped, and its Live Photo movie deleted")
    func deliveredTooLate() throws {
        let movieURL = try makeMovie()
        let finish = captures.begin(outcomes.add)
        captures.failAll()
        finish(.success(makePhoto(movieURL: movieURL)))
        #expect(outcomes.errors == [.notRunning])
        #expect(FileManager.default.fileExists(atPath: movieURL.path) == false)
    }

    @Test("A capture delivered in time keeps its Live Photo movie")
    func deliveredInTime() throws {
        let movieURL = try makeMovie()
        let finish = captures.begin(outcomes.add)
        finish(.success(makePhoto(movieURL: movieURL)))
        captures.failAll()
        #expect(outcomes.errors == [nil])
        #expect(FileManager.default.fileExists(atPath: movieURL.path))
    }
}
