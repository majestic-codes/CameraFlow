//
//  ExamplePhoto.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation

/// A photo the example kept: it takes over the files of a photo of the flow by moving them into its Documents
/// folder.
struct ExamplePhoto: Identifiable {
    let id: UUID
    let fileURL: URL
    let livePhotoMovieURL: URL?
    /// The copy with the drawing in `Documents/Edited`, nil when nothing was drawn.
    let editedFileURL: URL?
    /// A small picture of `resultFileURL`.
    let thumbnail: CGImage

    /// What the user finished: the edited copy when there is one, the original otherwise.
    var resultFileURL: URL {
        editedFileURL ?? fileURL
    }
}
