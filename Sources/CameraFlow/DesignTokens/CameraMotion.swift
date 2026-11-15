//
//  CameraMotion.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Animations and timings of the camera, grouped by component. The spring parameters are read from the stock
/// layers; where a number was measured or fitted, its comment says on what.
enum CameraMotion {
    static let easeInEaseOut = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.42, y: 0),
        endControlPoint: UnitPoint(x: 0.58, y: 1)
    )

    /// The lens buttons of the zoom control.
    enum Lens {
        static let press = Animation.interpolatingSpring(mass: 0.8, stiffness: 300, damping: 12)
        static let pressedScale: CGFloat = 0.85
        static let slide = Animation.timingCurve(easeInEaseOut, duration: 0.30)
        /// The glass circle of a lens that becomes active. The spring starts with a velocity of two lengths a second.
        static let circleFadeIn = Animation.interpolatingSpring(
            mass: 1,
            stiffness: 933.5,
            damping: 61.11,
            initialVelocity: 2
        )
        static let circleOut = Animation.timingCurve(easeInEaseOut, duration: 0.30)
    }

    /// The zoom dial.
    enum Dial {
        static let fadeIn = Animation.timingCurve(easeInEaseOut, duration: 0.23)
        static let fadeOut = Animation.timingCurve(easeInEaseOut, duration: 0.18)
        static let rise = Animation.interpolatingSpring(mass: 1, stiffness: 541.9, damping: 35.29)
        static let fall = Animation.interpolatingSpring(mass: 1, stiffness: 176.9, damping: 20.17)
        /// The current value of the dial as the dial collapses.
        static let valueFadeOut = Animation.interpolatingSpring(
            mass: 1,
            stiffness: 2608.7,
            damping: 102.15,
            initialVelocity: 2
        )
    }

    /// Springs of the control panel, fitted frame by frame to the card edge in `device/a-panel.mov`.
    ///
    /// Fit (mass 1): open omega 12.5 zeta 0.96, tile to sub-panel omega 13.0 zeta 1.04, back omega 12.75 zeta 1.04.
    /// The close shrinks the card into the shutter with 90 % of the travel in about 185 ms.
    enum Panel {
        /// Opening the tiles, from the closed panel or back from a sub-panel: the two fits differ by 10 ms.
        static let toTiles = Animation.spring(response: 0.5, dampingFraction: 0.98)
        static let toSubPanel = Animation.spring(response: 0.483, dampingFraction: 1)
        static let close = Animation.spring(response: 0.3, dampingFraction: 1)
        static let dragSettle = Animation.spring(response: 0.35, dampingFraction: 0.86)

        /// The animation of a change of `panel` to the given presentation.
        static func animation(to presentation: CameraPanelPresentation) -> Animation {
            switch presentation {
            case .hidden: close
            case .tiles: toTiles
            case .subPanel: toSubPanel
            }
        }
    }

    /// The indicators of the changed settings joining and leaving the top bar, and the bar re-centring on them.
    enum TopBar {
        static let change = Animation.spring(response: 0.35, dampingFraction: 0.9)
        static let indicatorAppearScale: CGFloat = 0.6
    }

    /// The elements that stay upright as the phone turns, all on one critically damped spring, so every element
    /// turns in step. The stock SwiftUI chrome fits such a spring with a response of 0.50 to 0.55 s on 30 Hz tracks
    /// of the top bar, the side buttons and the panel tiles.
    enum Rotation {
        static let element = Animation.spring(response: 0.5, dampingFraction: 1)
    }

    /// The focus reticle, measured on the stock camera of iOS 27.
    enum Reticle {
        /// Scale from `CameraMetrics.FocusReticle.appearScale` to 1: a keyframe animation of 0.2 s with the curve
        /// (0.42, 0, 1, 1).
        static let settle = Animation.timingCurve(0.42, 0, 1, 1, duration: 0.2)
        /// Opacity 0 to 1 on appear, 1 to the dimmed value on dimming and 1 to 0 on hiding: 0.25 s ease in-out.
        static let fade = Animation.easeInOut(duration: 0.25)
        /// The slider rail shows at once and fades 1 s after the last change.
        static let railFade = Animation.easeInOut(duration: 0.36)
        static let railHoldDuration = Duration.seconds(1)
        /// Opacity of the square while focusing: 1 to the pulse opacity and back in 0.18 s each way. The square pulses
        /// for two round trips after a tap, and over and over while a lock is on its way.
        static let pulseHalfCycle = 0.18
        /// Time at full brightness after the reticle appears, measured on the stock recording.
        static let fullBrightnessDuration = Duration.milliseconds(4050)
    }

    enum Shutter {
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.75)
        static let pressedScale: CGFloat = 0.88
        /// Seconds the spinner of a busy shutter takes for one turn. The stock spinner's speed was not measured.
        static let spinnerTurn: TimeInterval = 1
    }

    /// The flash of the viewfinder when a photo is taken.
    enum Capture {
        static let blinkIn = Animation.linear(duration: 0.05)
        static let blinkOut = Animation.easeOut(duration: 0.2)
    }

    /// The still that covers a picture while the camera behind it changes. None of it was measured on the stock
    /// camera.
    enum PictureCover {
        /// The still blurring once it covers the picture.
        static let blurDuration = 0.15
        /// How long the still stays after the new camera was started, for its first frames to reach the screen.
        static let holdDuration = 0.1
        /// The still fading out over the live picture.
        static let fadeDuration = 0.25
    }

    /// The self-timer countdown. None of it was measured on the stock camera.
    enum Countdown {
        static let tickDuration = 0.25
    }

    /// The notice capsule. None of it was measured on the stock camera.
    enum Notice {
        static let duration = 0.2
    }
}
#endif
