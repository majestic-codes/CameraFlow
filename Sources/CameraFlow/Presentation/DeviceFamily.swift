//
//  DeviceFamily.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The kind of device the flow runs on, which a text names where the stock camera's names it.
enum DeviceFamily: Sendable, Equatable {
    case phone
    case pad
}
