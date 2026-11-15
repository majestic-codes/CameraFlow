//
//  ExpiringActivityWork.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import Foundation

/// Background time from the system, through `ProcessInfo.performExpiringActivity`, which an app and its extensions
/// alike may ask for. One activity covers every work that runs: it begins with the first and ends with the last, so
/// work that overlaps holds one background thread.
@MainActor
final class ExpiringActivityWork: BackgroundWork {
    private var runningCount = 0
    private var activity: ExpiringActivity?

    func run<Result>(named name: String, _ work: () async -> Result) async -> Result {
        begin(named: name)
        defer { end() }
        return await work()
    }

    private func begin(named name: String) {
        runningCount += 1
        guard activity == nil else { return }
        let activity = ExpiringActivity()
        self.activity = activity
        ProcessInfo.processInfo.performExpiringActivity(withReason: name) { isExpired in
            activity.hold(isExpired: isExpired)
        }
    }

    private func end() {
        runningCount -= 1
        guard runningCount == 0 else { return }
        activity?.end()
        activity = nil
    }
}

/// One activity of the system. The system keeps the app running while the activity's block waits on a queue of its
/// own, until the work ends or the system takes the time back.
private final class ExpiringActivity: Sendable {
    private let ended = DispatchSemaphore(value: 0)

    /// Called by the system: first to begin the activity, and again with `isExpired` when the time is up, which lets
    /// the waiting block return.
    func hold(isExpired: Bool) {
        guard !isExpired else {
            ended.signal()
            return
        }
        ended.wait()
    }

    func end() {
        ended.signal()
    }
}
#endif
