//
//  FakeHeading.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 13.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@_spi(Testing) @testable import CameraFlow

/// A compass a test sets by hand: it records what the camera told it and returns the heading it was given while it
/// follows, between `start` and `stop`. Like the device's compass it has no reading while it does not follow.
@MainActor
final class FakeHeading: PhotoHeadingSource {
    /// `start` and `stop` in the order they came.
    private(set) var followCalls: [Bool] = []
    /// The quarters the phone was held in, in the order the camera reported them.
    private(set) var orientations: [CameraOrientation] = []
    /// How many times the heading was read.
    private(set) var readCount = 0
    /// What `heading` returns while the compass follows.
    var currentHeading: PhotoHeading?

    init(heading: PhotoHeading? = nil) {
        currentHeading = heading
    }

    func start() {
        followCalls.append(true)
    }

    func stop() {
        followCalls.append(false)
    }

    func deviceOrientationChanged(to orientation: CameraOrientation) {
        orientations.append(orientation)
    }

    var heading: PhotoHeading? {
        readCount += 1
        return isFollowing ? currentHeading : nil
    }

    private var isFollowing: Bool {
        followCalls.last == true
    }
}
