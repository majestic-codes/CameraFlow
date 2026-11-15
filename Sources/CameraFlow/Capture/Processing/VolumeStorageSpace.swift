//
//  VolumeStorageSpace.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The room left on the volume of a directory, as the system counts it for files the user asked for: with the
/// caches it deletes on demand, as the stock camera counts what it may purge. A volume that cannot say fails as the
/// writes of a flow do, without the folders of the directory in its text.
struct VolumeStorageSpace: StorageSpace {
    let directory: URL

    @concurrent
    func availableBytes() async throws -> Int64 {
        let values: URLResourceValues
        do {
            values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        } catch {
            throw StorageFailure.cameraError("Cannot read the room on the volume", cause: error)
        }
        guard let bytes = values.volumeAvailableCapacityForImportantUsage else {
            throw CameraServiceError.cannotStore("The volume does not say how much room it has")
        }
        return bytes
    }
}
