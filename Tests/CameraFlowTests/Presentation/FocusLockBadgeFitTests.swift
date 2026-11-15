//
//  FocusLockBadgeFitTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

/// The AE/AF LOCK badge of every language in its tray, and its AE LOCK and AF LOCK: at every stock size of the badge,
/// in every window, beside the second camera's circle or not, the text fits at its smallest scale at most. A phone is
/// held every way, and an iPad the way its interface stands, which turns with it.
@Suite("The AE/AF LOCK badge of every language", .serialized, .timeLimit(.minutes(2)))
struct FocusLockBadgeFitTests {
    static let languages = StringCatalog.languages.sorted()
    /// The keys of the badge of the focus and the exposure, of the exposure alone and of the focus alone.
    private static let badgeKeys = [
        "camera.focusLock.badge",
        "camera.focusLock.badge.exposure",
        "camera.focusLock.badge.focus"
    ]
    /// The sizes of the stock badge from the smallest text size to the largest.
    private static let sizes = [CameraTextStyle.focusLockBadge.size, 15, 17, 19]
    /// Every window with the ways it is held, as seen from its interface.
    private static let holds = LayoutWindow.phones.map { ($0, CameraOrientation.allCases) }
        + LayoutWindow.iPads.map { ($0, [CameraOrientation.portrait]) }

    @Test("The badge fits its tray, shrinking no further than its smallest scale", arguments: languages, badgeKeys)
    func badgeFits(language: String, key: String) throws {
        let badge = try StringCatalog.checkout().text(key, in: language)
        let inset = CameraMetrics.FocusLockBadge.textInset
        for size in Self.sizes {
            let ruler = TextRuler(.focusLockBadge(size: size), tracking: LetterTracking(language: language))
            let length = ruler.width(of: badge) + 2 * inset
            for (window, orientations) in Self.holds {
                let layout = window.layout()
                for orientation in orientations {
                    for isDualCameraCircleShown in [false, true] {
                        let placement = layout.focusLockBadge(
                            length: length,
                            isDualCameraCircleShown: isDualCameraCircleShown,
                            elementOrientation: orientation
                        )
                        let place = "\(size) pt in \(window.name), \(orientation), circle \(isDualCameraCircleShown)"
                        let scale = CameraMetrics.FocusLockBadge.minimumTextScale
                        expectFit(badge, ruler, within: placement.length - 2 * inset, scale: scale, place)
                    }
                }
            }
        }
    }

    @Test(
        "On a phone held upright without the circle, the badge of every language shows whole at its default size",
        arguments: badgeKeys
    )
    func wholeOnPhones(key: String) throws {
        let inset = CameraMetrics.FocusLockBadge.textInset
        for language in Self.languages {
            let badge = try StringCatalog.checkout().text(key, in: language)
            let ruler = TextRuler(.focusLockBadge, tracking: LetterTracking(language: language))
            let length = ruler.width(of: badge) + 2 * inset
            for window in LayoutWindow.phones {
                let placement = window.layout().focusLockBadge(
                    length: length,
                    isDualCameraCircleShown: false,
                    elementOrientation: .portrait
                )
                #expect(placement.length == length, "\(key) in \(language) in \(window.name)")
            }
        }
    }
}
#endif
