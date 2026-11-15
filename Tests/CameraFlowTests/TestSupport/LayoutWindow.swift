//
//  LayoutWindow.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@_spi(Testing) @testable import CameraFlow

/// A window the flow is laid out in: its size in points, the top safe area and the quarter of its interface.
struct LayoutWindow: Sendable, CustomTestStringConvertible {
    let name: String
    let size: CGSize
    let safeAreaTop: CGFloat
    var interfaceOrientation = CameraOrientation.portrait

    /// The phone the stock frames are measured on, which the layout tests take unless they name another window.
    static let referencePhone = Self(name: "iPhone 17 Pro", size: CGSize(width: 402, height: 874), safeAreaTop: 62)

    static let phones = [
        Self(name: "iPhone SE", size: CGSize(width: 375, height: 667), safeAreaTop: 20),
        Self(name: "iPhone mini", size: CGSize(width: 375, height: 812), safeAreaTop: 50),
        Self(name: "iPhone 17", size: CGSize(width: 393, height: 852), safeAreaTop: 59),
        referencePhone,
        Self(name: "iPhone Air", size: CGSize(width: 420, height: 912), safeAreaTop: 62),
        Self(name: "iPhone 17 Pro Max", size: CGSize(width: 440, height: 956), safeAreaTop: 62)
    ]

    /// The narrowest window the flow is laid out in: an iPad app in Slide Over.
    static let slideOver = landscape("Slide Over", CGSize(width: 320, height: 1000), .landscapeLeft)

    static let iPads = [
        Self(name: "iPad 11 portrait", size: CGSize(width: 834, height: 1210), safeAreaTop: 24),
        landscape("iPad 11 landscape", CGSize(width: 1210, height: 834), .landscapeLeft),
        Self(name: "iPad 13 portrait", size: CGSize(width: 1032, height: 1376), safeAreaTop: 24),
        landscape("iPad 13 upside down", CGSize(width: 1032, height: 1376), .upsideDown),
        landscape("iPad 13 landscape", CGSize(width: 1376, height: 1032), .landscapeRight),
        Self(name: "iPad mini portrait", size: CGSize(width: 744, height: 1133), safeAreaTop: 24),
        slideOver,
        Self(name: "Slide Over, portrait iPad", size: CGSize(width: 320, height: 1000), safeAreaTop: 24),
        landscape("Split View half, landscape iPad", CGSize(width: 678, height: 1032), .landscapeLeft),
        Self(name: "Split View third, portrait iPad", size: CGSize(width: 375, height: 1376), safeAreaTop: 24),
        Self(name: "Split View half, portrait iPad", size: CGSize(width: 512, height: 1376), safeAreaTop: 24)
    ] + shortWindows

    /// Windows of Stage Manager shorter than the stock arrangement, which shrink the column and the grid of tiles.
    static let shortWindows = [
        Self(name: "Short window, portrait iPad", size: CGSize(width: 500, height: 500), safeAreaTop: 24),
        landscape("Short window, landscape iPad", CGSize(width: 700, height: 500), .landscapeLeft),
        landscape("Shortest window, landscape iPad", CGSize(width: 600, height: 420), .landscapeRight)
    ]

    /// An iPad window whose interface stands in another quarter than portrait.
    private static func landscape(_ name: String, _ size: CGSize, _ orientation: CameraOrientation) -> Self {
        Self(name: name, size: size, safeAreaTop: 24, interfaceOrientation: orientation)
    }

    static let all = phones + iPads

    var testDescription: String {
        name
    }

    var bounds: CGRect {
        CGRect(origin: .zero, size: size)
    }

    /// Whether the interface stands in landscape, so the viewfinder is wider than tall.
    var isLandscape: Bool {
        [CameraOrientation.landscapeLeft, .landscapeRight].contains(interfaceOrientation)
    }

    /// The layout in the window: a 4:3 viewfinder, the panel hidden and eight tiles, unless the test says otherwise.
    func layout(
        aspectRatio: CameraFlowAspectRatio = .fourByThree,
        panel: CameraPanelPresentation = .hidden,
        panelTileCount: Int = 8
    ) -> CameraScreenLayout {
        CameraScreenLayout(
            size: size,
            safeAreaTop: safeAreaTop,
            aspectRatio: aspectRatio,
            panel: panel,
            panelTileCount: panelTileCount,
            interfaceOrientation: interfaceOrientation
        )
    }
}
