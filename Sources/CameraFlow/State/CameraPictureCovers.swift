//
//  CameraPictureCovers.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// The covers of the pictures on screen: the viewfinder's and, while it shows, the circle's. They cover their
/// pictures together before the camera changes and uncover them together once the new one runs.
@MainActor
final class CameraPictureCovers {
    private var covers: [WeakCover] = []

    private struct WeakCover {
        weak var cover: (any CameraPictureCover)?
    }

    /// Takes a cover for as long as it lives.
    func add(_ cover: any CameraPictureCover) {
        covers.removeAll { $0.cover == nil }
        covers.append(WeakCover(cover: cover))
    }

    func coverPictures() {
        covers.forEach { $0.cover?.coverPicture() }
    }

    func uncoverPictures() {
        covers.forEach { $0.cover?.uncoverPicture() }
    }
}
