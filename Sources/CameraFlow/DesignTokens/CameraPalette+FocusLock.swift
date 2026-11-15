//
//  CameraPalette+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import SwiftUI

extension CameraPalette {
    /// The plate of the AE/AF LOCK badge, the stock badges' yellow.
    static let focusLockBadge = accent
    /// The text of the badge, cut out of the plate and shaded so that the picture shows through it darkened.
    static let focusLockBadgeText = Color.black.opacity(CameraMetrics.FocusLockBadge.textOpacity)
}
