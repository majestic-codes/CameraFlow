//
//  DeleteConfirmation.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// The photo a delete would take out of the set and what would be lost with it, for the dialog that asks first.
struct DeleteConfirmation: Equatable, Sendable {
    let photoIdentifier: UUID
    /// A photo taken with the camera exists nowhere else. One from the photo library stays there.
    let source: CameraFlowPhoto.Source
    /// Whether a drawing on the photo goes with it.
    let hasDrawing: Bool

    init(photo: FlowPhoto) {
        photoIdentifier = photo.id
        source = photo.source
        hasDrawing = photo.hasDrawing
    }
}
