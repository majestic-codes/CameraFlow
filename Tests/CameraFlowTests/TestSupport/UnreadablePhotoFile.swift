//
//  UnreadablePhotoFile.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation

/// A photo file that no decoder reads: one that holds text, or one that is not there.
enum UnreadablePhotoFile: String, CaseIterable, Sendable {
    case text
    case missing

    /// The file in `directory` with the extension, written there when it holds text.
    func url(in directory: URL, fileExtension: String) throws -> URL {
        switch self {
        case .text:
            let url = directory.appendingPathComponent("notes").appendingPathExtension(fileExtension)
            try Data("no pixels here".utf8).write(to: url)
            return url
        case .missing:
            return directory.appendingPathComponent("missing").appendingPathExtension(fileExtension)
        }
    }
}
