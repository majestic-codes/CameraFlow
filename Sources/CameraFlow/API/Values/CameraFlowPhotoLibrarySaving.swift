//
//  CameraFlowPhotoLibrarySaving.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

/// Whether the flow saves the photos it takes to the system photo library, where, and whether the user decides.
///
/// A camera photo is saved as the camera's own file: full size, with all its metadata and location, and the Live
/// Photo movie paired with it. A photo picked from the library is never saved, and no photo is saved twice. When it
/// is saved is ``moment``:
///
/// - ``Moment/whenSetAccepted``, the default: nothing is saved while the set is open. When the user accepts the set,
///   every camera photo still in it is saved while saving is on. A photo the user deleted from the set, and every
///   photo of a set the user left with the cross, never reach the library. A photo with a drawing is saved as one
///   asset that shows the drawing and keeps the original, which the user can revert to in Photos. A Live Photo with
///   a drawing is saved as a still: its movie cannot show the drawing, so the asset has none, and reverting it in
///   Photos brings back the still photo.
/// - ``Moment/afterEachPhoto``: every camera photo taken while saving is on is saved right after the shot, as the
///   camera took it, while the user goes on shooting. That copy is the user's from then on: deleting the photo from
///   the set or leaving the flow with the cross does not take it out of the library, and a drawing added in the
///   review does not change it. The app receives the photo with the drawing all the same
///   (``CameraFlowPhoto/markedUp``), and the library keeps the photo without it. Switching saving on saves the photos
///   taken from then on, and switching it off keeps the ones saved. The exit alert counts a saved photo as kept.
///
/// Access to the library is asked for in the introduction of a flow that opens with saving on, when the user switches
/// saving on, or else at the first photo saved. A refusal (denied, restricted, or limited access for an album) leaves a
/// notice on the screen and switches off a saving the user may switch, and the Save sub-panel then offers the way to
/// the app's page of Settings, where the user can grant the access. A flow that opens with saving on over a refusal
/// the library already has says so from the start. A save that fails loses nothing: the photo stays in the set and is
/// handed over all the same, and the app reads ``CameraFlowPhoto/photoLibrarySave``. The screen says that it was not
/// saved: after each photo while the set is open, and when the user accepts the set the set stays open once with the
/// notice, and the next check mark saves the photos the library did not take and hands the set over whatever becomes
/// of them. A photo is reported as saved only once Photos created its asset, in the album too where the destination
/// is one: the asset and its place in the album are one change, and the photos are saved one after the other. The app
/// declares `NSPhotoLibraryAddUsageDescription` for the library and `NSPhotoLibraryUsageDescription` for an album: a
/// flow that may save without it stops the program when it starts.
public struct CameraFlowPhotoLibrarySaving: Sendable, Hashable {
    /// Where the photos go.
    ///
    /// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
    /// needs no `default`.
    public enum Destination: Sendable, Hashable {
        /// The library, with add-only access (`PHAccessLevel.addOnly`). Limited library access is enough.
        case library
        /// The album with this name, found or created, with read-write access (`PHAccessLevel.readWrite`). The name is
        /// not blank: a flow created with a blank one stops the program. Under limited library access albums are out
        /// of reach, so the save fails and reports it: the photo is not saved elsewhere instead.
        case album(named: String)
    }

    /// When a camera photo is saved.
    ///
    /// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
    /// needs no `default`.
    public enum Moment: Sendable, Hashable {
        /// When the user accepts the set, with its drawing. The default.
        case whenSetAccepted
        /// Right after the shot, as the camera took it, without waiting for the set.
        case afterEachPhoto
    }

    /// Group 1 of ``CameraFlowConfiguration``. Where the photos go. Default ``Destination/library``.
    public var destination = Destination.library
    /// Group 1 of ``CameraFlowConfiguration``. When the photos are saved. Default ``Moment/whenSetAccepted``.
    public var moment = Moment.whenSetAccepted
    /// Group 2 of ``CameraFlowConfiguration``. Whether saving is on, and whether the user may switch it: a Save
    /// indicator in the top bar and a Save tile in the "more" panel. Default off and fixed, so nothing is saved and
    /// no control is shown. Switching it on asks for library access there and then, and the switch stays off with a
    /// notice when access is refused. The user's choice is ``CameraFlowPreferences/isPhotoLibrarySavingEnabled``.
    public var isEnabled = CameraFlowSetting.fixed(false)

    /// Creates the saving of the default flow: nothing is saved. Change the properties that should differ.
    public init() {}

    /// Whether the flow saves at all: now, or once the user switches saving on.
    var isPossible: Bool {
        isEnabled.canBeOn
    }

    /// Stops the program on a destination no save can reach.
    /// - Precondition: an album name is not blank: it has a character besides white space.
    func validate() {
        if case let .album(name) = destination {
            precondition(
                !name.allSatisfy(\.isWhitespace),
                "CameraFlowPhotoLibrarySaving.Destination.album needs a name that is not blank"
            )
        }
    }
}

/// What became of a camera photo in the system photo library: it was saved or it failed, and there is no other
/// outcome.
///
/// The cases are fixed for 1.x: a new value comes as a new type or property, never as a new case, so a `switch`
/// needs no `default`. A `switch` that matches the failures inside ``failed(_:)`` one by one also needs
/// `@unknown default`, or a plain `case .failed:` last, since ``CameraFlowPhotoLibrarySaveFailure`` may gain cases.
public enum CameraFlowPhotoLibrarySave: Sendable, Hashable {
    /// The photo is in the library, as this asset.
    case saved(CameraFlowPhotoLibraryAsset)
    /// The photo is not in the library. Its file is handed over all the same.
    case failed(CameraFlowPhotoLibrarySaveFailure)
}

/// The asset a camera photo became in the system photo library.
public struct CameraFlowPhotoLibraryAsset: Sendable, Hashable {
    /// `PHAsset.localIdentifier` of the asset, for an app with library access to find it.
    public let localIdentifier: String
    /// Whether the photo is handed over with a drawing the asset does not show. The photo was saved right after its
    /// shot (``CameraFlowPhotoLibrarySaving/Moment/afterEachPhoto``), at a check mark before the drawing changed, or
    /// Photos could not take the drawing while it created the asset, which then shows the photo without it. False
    /// for a photo handed over without a drawing.
    public let isMissingDrawing: Bool

    /// Creates the asset as the flow reports it, for an app's own tests and previews.
    /// - Parameters:
    ///   - localIdentifier: `PHAsset.localIdentifier` of the asset.
    ///   - isMissingDrawing: Whether the photo is handed over with a drawing the asset does not show. Default false.
    public init(localIdentifier: String, isMissingDrawing: Bool = false) {
        self.localIdentifier = localIdentifier
        self.isMissingDrawing = isMissingDrawing
    }
}

/// Why a photo could not be saved to the system photo library.
///
/// A minor release may add cases, so a `switch` over a failure needs `@unknown default`.
@nonexhaustive
public enum CameraFlowPhotoLibrarySaveFailure: Error, Sendable, Hashable {
    /// The user refused the access the save needs, now or earlier.
    case accessDenied
    /// A device policy blocks the photo library and the user cannot change it.
    case accessRestricted
    /// The app may reach selected photos only, which leaves albums out of reach.
    case limitedAccess
    /// The library did not take the photo, for the reason of the ``CameraFlowPhotoLibraryError``.
    case libraryError(CameraFlowPhotoLibraryError)
}

/// Why the system photo library did not take a photo it was given.
///
/// A minor release may add cases, so a `switch` over an error needs `@unknown default`.
@nonexhaustive
public enum CameraFlowPhotoLibraryError: Error, Sendable, Hashable {
    /// Photos refused the change with the error of this domain and code, as its `NSError` has them. In
    /// `PHPhotosErrorDomain` the code is the raw value of a `PHPhotosError.Code`, such as
    /// `PHPhotosError.Code.invalidResource`: `PHPhotosError.Code(rawValue: errorCode)` reads it.
    case changeRefused(errorDomain: String, errorCode: Int)
    /// The device has too little room left for the photo (`PHPhotosError.Code.notEnoughSpace`, or the same from
    /// the file system), or for the photo with the drawing it is saved with. Nothing was added to the library.
    case notEnoughSpace
    /// The change went through without an asset to show for it.
    case noAssetCreated
    /// The photo with the drawing could not be rendered as the edit of the asset. Nothing was added to the library.
    case drawingNotWritten
    /// The album the photo goes into takes no photo. Nothing was added to the library.
    case albumNotWritable
}

extension CameraFlowPhotoLibrarySaveFailure: CustomStringConvertible {
    /// What went wrong, in English for the app's logs. The flow tells the user in words of its own.
    public var description: String {
        switch self {
        case .accessDenied: "The user denied access to the photo library"
        case .accessRestricted: "A device policy restricts access to the photo library"
        case .limitedAccess: "Limited access to the photo library leaves albums out of reach"
        case let .libraryError(error): "The photo library did not take the photo: \(error)"
        }
    }
}

extension CameraFlowPhotoLibraryError: CustomStringConvertible {
    /// What went wrong, in English for the app's logs, with the domain and the code of an error Photos refused the
    /// change with.
    public var description: String {
        switch self {
        case let .changeRefused(errorDomain, errorCode): "Photos refused the change: \(errorDomain) \(errorCode)"
        case .notEnoughSpace: "The device has too little room left for the photo"
        case .noAssetCreated: "The change went through without an asset"
        case .drawingNotWritten: "The photo with the drawing could not be rendered as the edit of the asset"
        case .albumNotWritable: "The album takes no photo"
        }
    }
}
