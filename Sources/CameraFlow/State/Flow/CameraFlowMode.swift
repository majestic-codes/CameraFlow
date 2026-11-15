//
//  CameraFlowMode.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The two modes of the flow screen, which share its bottom bar.
enum CameraFlowMode: Equatable, Sendable {
    /// The camera.
    case shooting
    /// The photos of the set.
    case review
}
