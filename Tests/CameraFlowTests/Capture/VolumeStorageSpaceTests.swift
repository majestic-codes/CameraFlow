//
//  VolumeStorageSpaceTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The room left on the volume of a directory, read without naming the folders of the directory in a failure.
@Suite("The room on a volume", .temporaryDirectory)
struct VolumeStorageSpaceTests {

    @Test("The volume of a directory says how much room it has")
    func room() async throws {
        let bytes = try await VolumeStorageSpace(directory: TestDirectory.current).availableBytes()
        #expect(bytes > 0)
    }

    @Test("A directory whose volume cannot be read fails as a write of the flow, without its folders")
    func unreadableVolume() async throws {
        let directory = TestDirectory.current.appendingPathComponent("Missing", isDirectory: true)
        let thrown = await #expect(throws: CameraServiceError.self) {
            _ = try await VolumeStorageSpace(directory: directory).availableBytes()
        }
        guard case let .cannotStore(reason) = try #require(thrown) else {
            Issue.record("The failure is \(String(describing: thrown))")
            return
        }
        #expect(reason.hasPrefix("Cannot read the room on the volume"))
        #expect(reason.contains(directory.path) == false)
        #expect(reason.contains(TestDirectory.current.path) == false)
    }
}
