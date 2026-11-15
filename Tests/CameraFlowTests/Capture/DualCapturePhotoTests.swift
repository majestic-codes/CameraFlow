//
//  DualCapturePhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Dual capture: the photo of the two cameras")
struct DualCapturePhotoTests {
    private static let movie = URL(fileURLWithPath: "/tmp/live.mov")
    private static let main = CapturedPhoto(imageData: Data([1]), encoding: .heif, livePhotoMovieURL: movie)
    private static let circle = CapturedPhoto(imageData: Data([2]), encoding: .heif, livePhotoMovieURL: nil)
    private static let failure = CameraServiceError.captureFailed("The camera gave nothing")

    private func combining(
        main: Result<CapturedPhoto, any Error>,
        circle: Result<CapturedPhoto, any Error>
    ) -> Result<CapturedPhoto, any Error> {
        DualCapturePhoto.combining(main: main, circle: circle, isViewfinderMirrored: true, viewfinderQuarterTurns: 3)
    }

    @Test("Both photos make the main photo with the circle's frame")
    func both() throws {
        let photo = try combining(main: .success(Self.main), circle: .success(Self.circle)).get()
        let frame = CircleCameraFrame(
            imageData: Self.circle.imageData,
            isViewfinderMirrored: true,
            viewfinderQuarterTurns: 3
        )
        #expect(photo.circleCameraFrame == frame)
        #expect(photo.livePhotoMovieURL == Self.movie)
        #expect(photo.losses.isEmpty)
    }

    @Test("A failed circle leaves the main photo, its movie kept, marked as without its circle")
    func circleFailed() throws {
        let photo = try combining(main: .success(Self.main), circle: .failure(Self.failure)).get()
        #expect(photo.circleCameraFrame == nil)
        #expect(photo.imageData == Self.main.imageData)
        #expect(photo.livePhotoMovieURL == Self.movie)
        #expect(photo.losses == [.circleCameraFrame])
    }

    @Test("A failed main photo fails the capture, whatever the circle did", arguments: [true, false])
    func mainFailed(circleSucceeded: Bool) {
        let circle: Result<CapturedPhoto, any Error> = circleSucceeded ? .success(Self.circle) : .failure(Self.failure)
        #expect(throws: Self.failure) {
            try combining(main: .failure(Self.failure), circle: circle).get()
        }
    }
}
