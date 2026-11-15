//
//  StorageFailureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// A write that failed for want of room, told from one that failed for any other cause.
@Suite("A write that failed for want of room", .temporaryDirectory)
struct StorageFailureTests {
    /// Foundation's out-of-space error with a POSIX cause beneath another error.
    private static let wrappedOutOfSpace = CocoaError(
        .fileWriteUnknown,
        userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOSPC)]
    )

    @Test(
        "A full volume or an exceeded quota is out of space, also beneath another error",
        arguments: [
            CocoaError(.fileWriteOutOfSpace) as any Error,
            POSIXError(.ENOSPC),
            POSIXError(.EDQUOT),
            wrappedOutOfSpace
        ]
    )
    func outOfSpace(error: any Error) {
        #expect(StorageFailure.isOutOfSpace(error))
        #expect(StorageFailure.cameraError("Cannot write the photo file", cause: error) == .notEnoughStorage)
    }

    @Test(
        "Any other failure is not, and keeps its words",
        arguments: [
            CocoaError(.fileWriteNoPermission) as any Error,
            CocoaError(.fileWriteFileExists),
            POSIXError(.EACCES),
            CameraServiceError.captureFailed("Something else")
        ]
    )
    func otherFailure(error: any Error) {
        #expect(StorageFailure.isOutOfSpace(error) == false)
        let failure = StorageFailure.cameraError("Cannot write the photo file", cause: error)
        #expect(failure == .cannotStore("Cannot write the photo file: \(error.localizedDescription)"))
    }

    @Test("A store whose directory cannot be made says why")
    func directoryNotMade() throws {
        let parent = TestDirectory.current.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: parent)
        let store = CaptureFileStore(parent: parent)
        #expect(throws: CameraServiceError.self) {
            try store.writePhoto(Data([1, 2, 3]), identifier: UUID(), type: .jpeg)
        }
    }
}
