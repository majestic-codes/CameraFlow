//
//  PhotoPosition.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The place of a photo in the set, as the review counts it: "3 of 5".
struct PhotoPosition: Equatable, Sendable {
    /// Counted from one.
    let number: Int
    let count: Int
}
