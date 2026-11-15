//
//  CameraLog.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os

extension Logger {

    /// A logger of the package, under its one subsystem.
    static func camera(_ category: String) -> Logger {
        Logger(subsystem: "CameraFlow", category: category)
    }
}
