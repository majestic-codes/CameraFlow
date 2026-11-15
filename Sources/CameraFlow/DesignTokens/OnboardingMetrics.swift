//
//  OnboardingMetrics.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// The introduction shown before the camera is asked for. The look is our own, in the manner of the system's
/// welcome screens: none of it was measured on the stock camera. Sizes of text and glyphs are at the default text
/// size and grow with Dynamic Type.
enum OnboardingMetrics {
    /// The widest the text column and the buttons get, on a wide screen.
    static let contentMaximumWidth: CGFloat = 420
    static let horizontalPadding: CGFloat = 28
    /// The least room above the symbol and under the last row.
    static let verticalPadding: CGFloat = 24

    /// The disc under the symbol at the top.
    static let heroDiameter: CGFloat = 88
    static let heroSymbolSize: CGFloat = 38
    static let heroRimWidth: CGFloat = 1
    static let heroToTitle: CGFloat = 20
    static let titleToRows: CGFloat = 36

    static let rowSpacing: CGFloat = 26
    /// The column the row glyphs are centred in.
    static let rowGlyphWidth: CGFloat = 40
    static let rowGlyphSize: CGFloat = 26
    static let rowGlyphToText: CGFloat = 14
    static let rowTitleToDetail: CGFloat = 2

    static let footnoteToButton: CGFloat = 16
    /// From the last row to the line about the request, where that line scrolls with the page.
    static let rowsToFootnote: CGFloat = 26
    static let buttonMinimumHeight: CGFloat = 50
    static let actionsTopPadding: CGFloat = 12
    static let actionsBottomPadding: CGFloat = 8

    static let detailOpacity = 0.62
    static let footnoteOpacity = 0.5
    static let pressedOpacity = 0.7
    static let busyOpacity = 0.5
    /// How far a step slides as it gives way to the next.
    static let stepSlide: CGFloat = 40
}
