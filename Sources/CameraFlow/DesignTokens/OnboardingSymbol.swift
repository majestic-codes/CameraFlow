//
//  OnboardingSymbol.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// SF Symbols of the introduction, the ones the system uses for the same things. The review and the saving to the
/// photo library show the symbols of the flow's own controls.
enum OnboardingSymbol: CaseIterable, Sendable {
    case camera
    /// Taking photos, in a row under the camera at the top.
    case capture
    /// Picking from the photo library.
    case libraryPicker
    /// The review of the set and the drawing on a photo, as on the Markup button of the review.
    case review
    /// Saving to the photo library, as on the Save indicator of the camera.
    case librarySave
    /// A copy of a photo going into the library.
    case copy
    /// Access that adds and cannot read.
    case addOnly
    case album
    /// The switch the user keeps in the camera.
    case userSwitch
    /// The location, at the top of its step.
    case location
    /// The place a photo was taken.
    case place
    /// Access while the app is in use.
    case inUse
    /// The user's say over the access, as the system's privacy glyph.
    case choice

    /// The name of the system symbol.
    var systemName: String {
        switch self {
        case .camera: "camera.fill"
        case .capture: "camera.viewfinder"
        case .libraryPicker: "photo.on.rectangle.angled"
        case .review: FlowSymbol.markup.rawValue
        case .librarySave: FlowSymbol.librarySave.rawValue
        case .copy: "square.and.arrow.down"
        case .addOnly: "lock.fill"
        case .album: "rectangle.stack"
        case .userSwitch: "switch.2"
        case .location: "location.fill"
        case .place: "mappin.and.ellipse"
        case .inUse: "location.circle"
        case .choice: "hand.raised.fill"
        }
    }
}
