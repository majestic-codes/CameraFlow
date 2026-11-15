//
//  CameraLayerHost.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Hosts a camera preview that only shows: it takes no touch.
struct CameraLayerHost: UIViewRepresentable {
    /// Makes the preview the host shows for as long as it lives.
    let makePreview: () -> any CameraPreview
    /// The covers the host's picture joins.
    let covers: CameraPictureCovers

    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView(preview: makePreview())
        view.isUserInteractionEnabled = false
        covers.add(view)
        return view
    }

    func updateUIView(_ view: PreviewLayerView, context: Context) {}
}
#endif
