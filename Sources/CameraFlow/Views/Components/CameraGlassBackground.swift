//
//  CameraGlassBackground.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Where a piece of camera glass sits, which decides how it is tuned.
enum CameraGlassStyle {
    /// A button on the black chrome that answers touches.
    case control
    /// Glass over the live preview, darkened the way the stock camera darkens it.
    case overPreview
}

/// Puts a view on the camera's glass: the system glass where it exists, a blurred and tinted imitation before it.
struct CameraGlassBackground<Outline: Shape>: ViewModifier {
    let outline: Outline
    let style: CameraGlassStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            switch style {
            case .control:
                content.glassEffect(.regular.interactive(), in: outline)
            case .overPreview:
                // The shade is a layer of its own: a tint passed to the glass renders differently on a device
                // and in the simulator.
                content.background {
                    ZStack {
                        Color.clear.glassEffect(.regular, in: outline)
                        outline.fill(CameraPalette.glassPreviewShade)
                    }
                }
            }
        } else {
            content.background {
                outline
                    .fill(.ultraThinMaterial)
                    .overlay(outline.fill(CameraPalette.glassImitationTint))
            }
        }
    }
}

extension View {

    func cameraGlass(_ style: CameraGlassStyle, in outline: some Shape = Circle()) -> some View {
        modifier(CameraGlassBackground(outline: outline, style: style))
    }
}
#endif
