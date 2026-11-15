//
//  ShutterBusyIndication.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// How the shutter shows that the camera takes no photo yet, as the stock camera's shutter shows it.
enum ShutterBusyIndication: Equatable {
    /// The shutter looks as ever: the camera is ready, or busy so briefly that a change would only distract.
    case unchanged
    /// The disc dims while the camera takes the photos asked for, such as one with the flash.
    case dimmed
    /// The disc dims and a spinner turns around it while the camera processes the photos it took.
    case spinning
}
