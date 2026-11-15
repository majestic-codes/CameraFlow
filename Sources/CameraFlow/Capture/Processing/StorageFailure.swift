//
//  StorageFailure.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// Tells a write that failed for want of room on the device from one that failed for any other cause.
enum StorageFailure {

    /// Whether the error says the volume is full: Foundation's out-of-space error, or POSIX's no space or exceeded
    /// quota, also as the underlying cause of a Foundation error.
    static func isOutOfSpace(_ error: any Error) -> Bool {
        if let posixError = error as? POSIXError {
            return posixError.code == .ENOSPC || posixError.code == .EDQUOT
        }
        guard let cocoaError = error as? CocoaError else { return false }
        if cocoaError.code == .fileWriteOutOfSpace {
            return true
        }
        guard let underlying = cocoaError.underlying else { return false }
        return isOutOfSpace(underlying)
    }

    /// The failure of a write into the directory of a flow: the missing room as it is, any other cause in words
    /// after what failed.
    static func cameraError(_ action: String, cause error: any Error) -> CameraServiceError {
        isOutOfSpace(error) ? .notEnoughStorage : .cannotStore("\(action): \(error.localizedDescription)")
    }
}
