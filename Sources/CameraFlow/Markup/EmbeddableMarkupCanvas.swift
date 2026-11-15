//
//  EmbeddableMarkupCanvas.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

/// A canvas together with the view controller that shows it.
///
/// The view of the view controller is the canvas: the screen gives it exactly the rectangle the photo is shown
/// in. The canvas keeps the size of the first rectangle it gets and is shown scaled into any later one, so the
/// drawing stays over the photo when the rectangle changes size. The system tool picker comes on screen with that
/// view and leaves with it.
@MainActor
protocol EmbeddableMarkupCanvas: MarkupCanvas {
    var viewController: UIViewController { get }
}
#endif
