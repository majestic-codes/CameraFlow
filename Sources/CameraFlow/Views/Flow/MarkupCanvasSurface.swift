//
//  MarkupCanvasSurface.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI
import UIKit

/// The canvas of the drawing mode, shown by the view controller of its engine. The system tool picker comes on
/// screen with the canvas and leaves with it.
struct MarkupCanvasSurface: UIViewControllerRepresentable {
    let canvas: EmbeddedMarkupCanvas

    func makeUIViewController(context: Context) -> UIViewController {
        canvas.viewController
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {}
}
#endif
