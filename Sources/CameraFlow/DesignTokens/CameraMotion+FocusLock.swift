//
//  CameraMotion+FocusLock.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

extension CameraMotion {
    /// The AE/AF Lock, read from the stock camera's code.
    enum FocusLock {
        /// How long a finger holds the viewfinder before it is a long press, as the stock recognizer waits.
        static let pressDuration: TimeInterval = 0.5
        /// The square of a long press shrinking to a tap's size as the finger lets go, and the sun coming back.
        static let release = Animation.easeInOut(duration: 0.25)
        /// One bounce of the square as the lock takes: from the grown size back to its own, with the stock curve.
        static let bounceDuration: TimeInterval = 0.3
        static let bounceCurve = UnitCurve.easeIn
        /// How long after the finger of a long press let go the square dims.
        static let releaseDimDelay = Duration.milliseconds(1200)
        /// The badge coming and going, as the stock badge tray shows its badges: a critically damped spring.
        static let badge = Animation.spring(duration: 0.5, bounce: 0)
        /// The badge moving to the edge that is up as the phone turns: the old place fades out while the new one
        /// fades in a little later, as the stock badge tray does.
        static var relocation: AnyTransition {
            .asymmetric(
                insertion: .opacity.animation(.timingCurve(easeInEaseOut, duration: 0.25).delay(0.2)),
                removal: .opacity.animation(.timingCurve(easeInEaseOut, duration: 0.3))
            )
        }
    }
}
#endif
