//
//  CameraGlyph.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics

/// Every glyph of the camera chrome. None of them ships as artwork: each is drawn while the app runs.
///
/// A glyph with a public system symbol is that symbol, by its name, so the system draws it in the design of the
/// running iOS. The stock camera draws the aspect ratios, the self-timer delays and the button of the control panel
/// with symbols of its own, which no app may use, so the package composes those: the ratio written in the public
/// viewfinder symbol, and its own timer dial and dots (`CameraGlyphOutline`). Every symbol named here is public from
/// iOS 17.
enum CameraGlyph: CaseIterable {
    case flashAuto
    /// Auto while the scene would not fire the flash, outlined for people who differentiate without colour: the
    /// stock indicator tells it from the lit one by its colour alone.
    case flashAutoUnlit
    case flashOn
    case flashOff
    /// A flash that cannot fire for a while, where the stock camera adds a warning to the bolt.
    case flashUnavailable
    case livePhotoOn
    case livePhotoOff
    case aspect4x3
    case aspect16x9
    case aspect1x1
    case timerOff
    case timer3
    case timer5
    case timer10
    case exposure
    case more
    case flip
    case back

    /// Where the glyph is drawn: each place has its own size, weight and symbol scale on the stock Camera.
    enum Placement: CaseIterable {
        /// Regular weight at 18.5 pt.
        case topBar
        /// Regular weight at 22 pt in the rows of a sub-panel.
        case optionRow
        /// Light weight at 22 pt and the large symbol scale in the tiles of the control panel.
        case tile
        /// Regular weight at 17 pt in the glass buttons, the flip at the large symbol scale.
        case button
    }

    /// What a glyph is drawn from.
    enum Artwork: Equatable {
        /// A public system symbol, by its name.
        case symbol(String)
        /// A public system symbol with a badge on its trailing side. The system frames such a symbol by its base
        /// alone, so the badge stands out of the frame (`CameraGlyphOutline.badgeShift`).
        case badgedSymbol(String)
        /// An aspect ratio such as "4:3", written in the public viewfinder symbol.
        case aspectRatio(String)
        /// The timer dial with the delay in seconds written in it, or struck through for no delay.
        case timer(seconds: Int?)
        /// The six dots of the button that opens the control panel.
        case controlDots
    }

    /// The weight of a glyph, as the system weighs its symbols.
    enum Weight: Equatable {
        case light
        case regular
    }

    /// The scale of a glyph against the text it stands with, as the system scales its symbols.
    enum Scale: Equatable {
        case medium
        case large
    }

    /// The size, the weight and the symbol scale of a glyph in its placement.
    struct Cut: Equatable {
        let pointSize: CGFloat
        let weight: Weight
        let scale: Scale
    }

    /// The public symbol the aspect ratios are written in: four corners of a frame.
    static let viewfinderSymbol = "viewfinder"

    var artwork: Artwork {
        switch self {
        case .flashAuto: .badgedSymbol("bolt.badge.automatic.fill")
        case .flashAutoUnlit: .badgedSymbol("bolt.badge.automatic")
        case .flashOn: .symbol("bolt.fill")
        case .flashOff: .symbol("bolt.slash.fill")
        case .flashUnavailable: .badgedSymbol("bolt.trianglebadge.exclamationmark.fill")
        case .livePhotoOn: .symbol("livephoto")
        case .livePhotoOff: .symbol("livephoto.slash")
        case .aspect4x3: .aspectRatio("4:3")
        case .aspect16x9: .aspectRatio("16:9")
        case .aspect1x1: .aspectRatio("1:1")
        case .timerOff: .timer(seconds: nil)
        case .timer3: .timer(seconds: 3)
        case .timer5: .timer(seconds: 5)
        case .timer10: .timer(seconds: 10)
        case .exposure: .symbol("plusminus")
        case .more: .controlDots
        case .flip: .symbol("arrow.triangle.2.circlepath")
        case .back: .symbol("chevron.backward")
        }
    }

    /// The place the glyph has on the stock screen.
    var defaultPlacement: Placement {
        switch self {
        case .flashAuto, .flashAutoUnlit, .flashOn, .flashOff, .flashUnavailable, .livePhotoOn, .livePhotoOff: .topBar
        case .aspect4x3, .aspect16x9, .aspect1x1, .timerOff, .timer3, .timer5, .timer10: .optionRow
        case .exposure: .tile
        case .more, .flip, .back: .button
        }
    }

    /// The cut the glyph is drawn in at a placement.
    func cut(in placement: Placement) -> Cut {
        let sizes = CameraMetrics.Symbol.self
        return switch placement {
        case .topBar: Cut(pointSize: sizes.topBarPointSize, weight: .regular, scale: .medium)
        case .optionRow: Cut(pointSize: sizes.regularPointSize, weight: .regular, scale: .medium)
        case .tile: Cut(pointSize: sizes.regularPointSize, weight: .light, scale: .large)
        case .button: Cut(pointSize: sizes.buttonPointSize, weight: .regular, scale: self == .flip ? .large : .medium)
        }
    }
}
