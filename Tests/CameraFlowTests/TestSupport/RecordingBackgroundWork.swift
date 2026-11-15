//
//  RecordingBackgroundWork.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

@testable import CameraFlow

/// Background time that runs the work as it is and records it: what began, in order, and how much runs now.
@MainActor
final class RecordingBackgroundWork: BackgroundWork {
    /// The names of the work that began, in order.
    private(set) var names: [String] = []
    /// How many of the works run now.
    private(set) var runningCount = 0

    func run<Result>(named name: String, _ work: () async -> Result) async -> Result {
        names.append(name)
        runningCount += 1
        defer { runningCount -= 1 }
        return await work()
    }
}
