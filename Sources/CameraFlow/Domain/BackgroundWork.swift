//
//  BackgroundWork.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Keeps the app running while work the user started ends in the background, such as a photo being written or a
/// set being handed over, so that leaving the app at once loses nothing. The system gives a while, not forever.
@MainActor
protocol BackgroundWork: AnyObject {

    /// Runs the work and returns what it returns. Should the app leave the foreground meanwhile, the system is asked
    /// to keep it running until the work ends.
    func run<Result>(named name: String, _ work: () async -> Result) async -> Result
}
