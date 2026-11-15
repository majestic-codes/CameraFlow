//
//  CapturePartsTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Parts of a capture: the photo whenever its still came through")
struct CapturePartsTests {
    private static let still = Data([1, 2, 3])
    private static let movie = URL(fileURLWithPath: "/tmp/live.mov")

    private func photo(
        of parts: CaptureParts,
        captureFailure: String? = nil
    ) -> Result<CapturedPhoto, CameraServiceError> {
        parts.photo(captureFailure: captureFailure, encoding: .heif, location: nil)
    }

    @Test("A still with its movie is a Live Photo that lacks nothing")
    func livePhoto() throws {
        var parts = CaptureParts(asksForMovie: true)
        parts.imageData = Self.still
        parts.movieURL = Self.movie
        let photo = try photo(of: parts).get()
        #expect(photo.imageData == Self.still)
        #expect(photo.livePhotoMovieURL == Self.movie)
        #expect(photo.losses.isEmpty)
    }

    @Test(
        "A still whose movie failed, by itself or with the capture, is a still that lacks its movie",
        arguments: [nil, "The capture failed with the movie"]
    )
    func movieFailed(captureFailure: String?) throws {
        var parts = CaptureParts(asksForMovie: true)
        parts.imageData = Self.still
        parts.movieFailure = "The disk is full"
        let photo = try photo(of: parts, captureFailure: captureFailure).get()
        #expect(photo.imageData == Self.still)
        #expect(photo.livePhotoMovieURL == nil)
        #expect(photo.losses == [.livePhotoMovie])
        #expect(parts.isMovieLost)
    }

    @Test("A still whose movie never came, with a failed capture, is a still that lacks its movie")
    func movieNeverCame() throws {
        var parts = CaptureParts(asksForMovie: true)
        parts.imageData = Self.still
        let photo = try photo(of: parts, captureFailure: "The capture failed").get()
        #expect(photo.livePhotoMovieURL == nil)
        #expect(photo.losses == [.livePhotoMovie])
    }

    @Test("A still the capture asked no movie for fails with the capture")
    func stillWithFailedCapture() {
        var parts = CaptureParts(asksForMovie: false)
        parts.imageData = Self.still
        #expect(throws: CameraServiceError.captureFailed("The capture failed")) {
            try photo(of: parts, captureFailure: "The capture failed").get()
        }
    }

    @Test("A Live Photo whose movie came fails with a capture that failed for another reason")
    func liveWithFailedCapture() {
        var parts = CaptureParts(asksForMovie: true)
        parts.imageData = Self.still
        parts.movieURL = Self.movie
        #expect(throws: CameraServiceError.captureFailed("The capture failed")) {
            try photo(of: parts, captureFailure: "The capture failed").get()
        }
    }

    @Test("A failed still fails the capture, its movie or not")
    func stillFailed() {
        var parts = CaptureParts(asksForMovie: true)
        parts.stillFailure = "The sensor gave nothing"
        parts.movieURL = Self.movie
        #expect(throws: CameraServiceError.captureFailed("The sensor gave nothing")) {
            try photo(of: parts).get()
        }
    }

    @Test("A capture without a still fails as one with no image data, or with its own failure")
    func noStill() {
        let parts = CaptureParts(asksForMovie: false)
        #expect(throws: CameraServiceError.noImageData) {
            try photo(of: parts).get()
        }
        #expect(throws: CameraServiceError.captureFailed("The capture failed")) {
            try photo(of: parts, captureFailure: "The capture failed").get()
        }
    }
}
