//
//  DarkSceneAppearance.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import UIKit

/// The dark appearance of a whole window scene, held while a canvas is on screen.
///
/// The system shows what belongs to the tool picker in a window of its own above the app's: PaperKit's shape
/// picker is a sheet in that window. The window takes its appearance from the scene, not from the app's window or
/// from a view controller, so a canvas in a dark screen makes the scene dark and gives it its own appearance back
/// as it leaves.
@MainActor
final class DarkSceneAppearance {
    /// What the scene was told to look like before a canvas made it dark.
    private enum PreviousAppearance {
        case systemOwn
        case overridden(UIUserInterfaceStyle)
    }

    private weak var scene: UIWindowScene?
    private var previousAppearance = PreviousAppearance.systemOwn

    /// Makes the scene dark, unless this appearance holds a scene already.
    func apply(to scene: UIWindowScene) {
        guard self.scene == nil else { return }
        let overrides = scene.traitOverrides
        let isOverridden = overrides.contains(UITraitUserInterfaceStyle.self)
        previousAppearance = isOverridden ? .overridden(overrides.userInterfaceStyle) : .systemOwn
        scene.traitOverrides.userInterfaceStyle = .dark
        self.scene = scene
    }

    /// Gives the scene the appearance it had before.
    func restore() {
        guard let scene else { return }
        switch previousAppearance {
        case .systemOwn:
            scene.traitOverrides.remove(UITraitUserInterfaceStyle.self)
        case let .overridden(style):
            scene.traitOverrides.userInterfaceStyle = style
        }
        self.scene = nil
    }
}
#endif
