//
//  RecordingPictureCover.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

/// A cover that records when its picture was covered and uncovered, each with the number of calls the camera had
/// taken by then.
@MainActor
final class RecordingPictureCover: CameraPictureCover {
    enum Event: Equatable {
        case covered(afterCalls: Int)
        case uncovered(afterCalls: Int)
    }

    private(set) var events: [Event] = []
    private(set) var isCovered = false
    private let service: RecordingCameraService

    init(countingCallsOf service: RecordingCameraService) {
        self.service = service
    }

    func coverPicture() {
        isCovered = true
        events.append(.covered(afterCalls: service.calls.count))
    }

    func uncoverPicture() {
        guard isCovered else { return }
        isCovered = false
        events.append(.uncovered(afterCalls: service.calls.count))
    }
}
