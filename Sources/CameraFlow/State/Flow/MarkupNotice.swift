//
//  MarkupNotice.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// What the drawing mode has to say when it could not do what was asked.
enum MarkupNotice: Equatable {
    /// The canvas could not be opened over the photo, so the review goes on.
    case cannotOpen
    /// The drawing on the canvas could not be read, so the canvas stays open.
    case cannotKeep
}
