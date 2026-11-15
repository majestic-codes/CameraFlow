//
//  LensZoomShift.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Moves a view without moving its layout, like `offset`, and animates inside `animation(_:body:)`, which
/// `offset` does not.
struct LensZoomShift: GeometryEffect {
    var translation: CGSize

    var animatableData: CGSize.AnimatableData {
        get { translation.animatableData }
        set { translation.animatableData = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: translation.width, y: translation.height))
    }
}
#endif
