//
//  CameraFlowPhotoLibraryErrorTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("What a failed save to the photo library says in the app's logs")
struct CameraFlowPhotoLibraryErrorTests {
    private static let refusal = CameraFlowPhotoLibraryError.changeRefused(
        errorDomain: "PHPhotosErrorDomain",
        errorCode: 3302
    )
    private static let refusalDescription = "Photos refused the change: PHPhotosErrorDomain 3302"

    @Test(
        "An error of the library says what went wrong, with the domain and the code of a refused change",
        arguments: [
            (refusal, refusalDescription),
            (.notEnoughSpace, "The device has too little room left for the photo"),
            (.noAssetCreated, "The change went through without an asset"),
            (.drawingNotWritten, "The photo with the drawing could not be rendered as the edit of the asset"),
            (.albumNotWritable, "The album takes no photo")
        ]
    )
    func libraryError(error: CameraFlowPhotoLibraryError, description: String) {
        #expect(String(describing: error) == description)
    }

    @Test(
        "A failure says what went wrong, with the error of the library in it",
        arguments: [
            (CameraFlowPhotoLibrarySaveFailure.accessDenied, "The user denied access to the photo library"),
            (.accessRestricted, "A device policy restricts access to the photo library"),
            (.limitedAccess, "Limited access to the photo library leaves albums out of reach"),
            (.libraryError(refusal), "The photo library did not take the photo: \(refusalDescription)")
        ]
    )
    func saveFailure(failure: CameraFlowPhotoLibrarySaveFailure, description: String) {
        #expect(String(describing: failure) == description)
    }

    @Test("Two refusals with the same domain and code are the same failure")
    func equality() {
        #expect(Self.refusal == .changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3302))
        #expect(Self.refusal != .changeRefused(errorDomain: "PHPhotosErrorDomain", errorCode: 3303))
        #expect(Self.refusal != .changeRefused(errorDomain: "NSCocoaErrorDomain", errorCode: 3302))
    }
}
