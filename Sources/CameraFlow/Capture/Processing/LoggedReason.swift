//
//  LoggedReason.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import os

/// Why something failed, in the two parts a log message shows it in: the summary, which every build shows, and the
/// details, which only show where the log shows private data. The details hold what may describe the user or the
/// device: the values of a photo's metadata, and the folders and the names of the files of the device.
struct LoggedReason: Equatable, Sendable, CustomStringConvertible {
    let summary: String
    /// Empty for a reason without details.
    let details: String

    init(_ summary: String, details: String = "") {
        self.summary = summary
        self.details = details
    }

    /// An error as a log shows it. The package's errors of a photo file and of a drawing are summaries whole: their
    /// texts name no file but the package's own, without its folders. Any other error has its localized description
    /// as its summary, which names a file without its folders, and its full description as its details.
    init(_ error: any Error) {
        switch error {
        case is CameraServiceError, is PhotoOutputFailure, is MarkupFailure:
            self.init(String(describing: error))
        default:
            self.init(error.localizedDescription, details: String(describing: error))
        }
    }

    var description: String {
        details.isEmpty ? summary : "\(summary) (\(details))"
    }
}

extension Logger {

    /// Logs an error after what failed: its summary in every build, its details only where the log shows private
    /// data.
    func error(_ action: StaticString, cause: any Error) {
        let actionText = String(describing: action)
        let reason = LoggedReason(cause)
        let summary = reason.summary
        let details = reason.details
        if details.isEmpty {
            error("\(actionText, privacy: .public): \(summary, privacy: .public)")
        } else {
            error("\(actionText, privacy: .public): \(summary, privacy: .public) (\(details, privacy: .private))")
        }
    }

    /// Logs what happened and why: the summary of the reason in every build, its details only where the log shows
    /// private data.
    func info(_ event: StaticString, reason: LoggedReason) {
        let eventText = String(describing: event)
        let summary = reason.summary
        let details = reason.details
        if details.isEmpty {
            info("\(eventText, privacy: .public): \(summary, privacy: .public)")
        } else {
            info("\(eventText, privacy: .public): \(summary, privacy: .public) (\(details, privacy: .private))")
        }
    }
}
