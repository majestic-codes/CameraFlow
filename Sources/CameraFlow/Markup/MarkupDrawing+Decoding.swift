//
//  MarkupDrawing+Decoding.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import PaperKit
import PencilKit

extension MarkupDrawing {

    /// The drawing as PencilKit reads it. Fails with `MarkupFailure.undecodableDrawing`.
    func pencilDrawing() throws -> PKDrawing {
        do {
            return try PKDrawing(data: data)
        } catch {
            throw MarkupFailure.undecodableDrawing(engine, error.localizedDescription)
        }
    }

    /// The drawing as PaperKit reads it. Fails with `MarkupFailure.undecodableDrawing`.
    @available(iOS 26, macOS 26, *)
    func paperMarkup() throws -> PaperMarkup {
        do {
            return try PaperMarkup(dataRepresentation: data)
        } catch {
            throw MarkupFailure.undecodableDrawing(engine, String(describing: error))
        }
    }
}
