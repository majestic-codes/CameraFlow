//
//  CapturesInFlight.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os

/// The captures a camera has fired and not yet delivered. Each ends exactly once: with what the camera delivers,
/// or with `CameraServiceError.notRunning` when its session stops, fails or is set up again first, so no capture
/// waits for a session that is gone.
final class CapturesInFlight: Sendable {
    typealias Completion = @Sendable (Result<CapturedPhoto, any Error>) -> Void

    private struct State {
        var completions: [UUID: Completion] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Takes a capture in and returns how to end it. What the camera delivers after the capture has ended is
    /// dropped, and a Live Photo movie that came with it is deleted, since nobody receives it.
    func begin(_ completion: @escaping Completion) -> Completion {
        let identifier = UUID()
        state.withLock { $0.completions[identifier] = completion }
        return { [state] result in
            let completion = state.withLock { $0.completions.removeValue(forKey: identifier) }
            guard let completion else {
                if case let .success(photo) = result, let movieURL = photo.livePhotoMovieURL {
                    CaptureFileStore.discard(movieURL)
                }
                return
            }
            completion(result)
        }
    }

    /// Ends every capture in flight with `CameraServiceError.notRunning`.
    func failAll() {
        let completions = state.withLock { state in
            defer { state.completions = [:] }
            return Array(state.completions.values)
        }
        completions.forEach { $0(.failure(CameraServiceError.notRunning)) }
    }
}
