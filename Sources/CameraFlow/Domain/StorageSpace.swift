//
//  StorageSpace.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The room left on the volume the photos are written to.
protocol StorageSpace: Sendable {

    /// The bytes free for files the user asked for, with what the system frees for them on demand. Throws when the
    /// volume does not say.
    func availableBytes() async throws -> Int64
}
