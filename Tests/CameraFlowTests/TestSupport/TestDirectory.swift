//
//  TestDirectory.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing

/// The temporary directory of the running test. Every file and directory a test makes goes under it, and the
/// `.temporaryDirectory` trait removes it with everything in it when the test ends, also when the test fails. A
/// directory that cannot be removed is an issue of its own, beside the test's own failure.
enum TestDirectory {
    @TaskLocal static var scoped: URL?

    /// The directory of the running test. A test whose suite lacks the trait fails here and gets a directory nothing
    /// removes.
    static var current: URL {
        if let scoped {
            return scoped
        }
        Issue.record("The test uses temporary files: add the `.temporaryDirectory` trait to its suite")
        return FileManager.default.temporaryDirectory.appendingPathComponent("CameraFlowTests-unscoped")
    }
}

/// Gives every test of a suite, and every case of a test with arguments, a temporary directory of its own.
struct TemporaryDirectoryTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool {
        true
    }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CameraFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record(error, "The temporary directory of the test cannot be removed")
            }
        }
        try await TestDirectory.$scoped.withValue(directory) { try await function() }
    }
}

extension Trait where Self == TemporaryDirectoryTrait {
    /// A temporary directory for each test, removed when the test ends.
    static var temporaryDirectory: Self {
        Self()
    }
}
