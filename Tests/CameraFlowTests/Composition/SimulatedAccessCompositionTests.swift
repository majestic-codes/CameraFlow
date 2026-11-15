//
//  SimulatedAccessCompositionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// What a flow over the simulated camera opens with under one access, as `SimulatedAccess` documents it.
struct SimulatedAccessCase: Sendable, CustomTestStringConvertible {
    let access: SimulatedAccess
    let grantsCameraBefore: Bool
    let cameraAnswer: CameraAuthorization
    let photoLibrary: SimulatedAccess.PhotoLibrary
    let location: SimulatedAccess.Location

    static let simulatedGranted = SimulatedAccess.Location.simulated(
        authorization: .authorized,
        answerOnRequest: .authorized
    )
    static let simulatedUnasked = SimulatedAccess.Location.simulated(
        authorization: .notDetermined,
        answerOnRequest: .authorized
    )

    static let all = [
        Self(
            access: .granted,
            grantsCameraBefore: true,
            cameraAnswer: .authorized,
            photoLibrary: .system,
            location: .system
        ),
        Self(
            access: .cameraNotAsked,
            grantsCameraBefore: false,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: true),
            location: simulatedGranted
        ),
        Self(
            access: .cameraDenied,
            grantsCameraBefore: false,
            cameraAnswer: .denied,
            photoLibrary: .system,
            location: .system
        ),
        Self(
            access: .cameraAndPhotoLibraryNotAsked,
            grantsCameraBefore: false,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: false),
            location: simulatedGranted
        ),
        Self(
            access: .locationNotAsked,
            grantsCameraBefore: true,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: true),
            location: simulatedUnasked
        ),
        Self(
            access: .locationDenied,
            grantsCameraBefore: true,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: true),
            location: .simulated(authorization: .notDetermined, answerOnRequest: .denied)
        ),
        Self(
            access: .cameraLocationAndPhotoLibraryNotAsked,
            grantsCameraBefore: false,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: false),
            location: simulatedUnasked
        ),
        Self(
            access: .photoLibraryNotAsked,
            grantsCameraBefore: true,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: false),
            location: simulatedGranted
        ),
        Self(
            access: .locationAndPhotoLibraryNotAsked,
            grantsCameraBefore: true,
            cameraAnswer: .authorized,
            photoLibrary: .simulated(isAuthorizationDetermined: false),
            location: simulatedUnasked
        )
    ]

    var testDescription: String {
        "\(access)"
    }
}

@Suite("What a flow over the simulated camera opens with under each simulated access")
struct SimulatedAccessCompositionTests {

    @Test(
        "The camera was granted before or is asked, and answers as the access says",
        arguments: SimulatedAccessCase.all
    )
    func camera(accessCase: SimulatedAccessCase) {
        #expect(accessCase.access.grantsCameraBefore == accessCase.grantsCameraBefore)
        #expect(accessCase.access.cameraAnswer == accessCase.cameraAnswer)
    }

    @Test(
        "The photo library is the system's or a simulated one, granted before or when asked",
        arguments: SimulatedAccessCase.all
    )
    func photoLibrary(accessCase: SimulatedAccessCase) {
        #expect(accessCase.access.photoLibrary == accessCase.photoLibrary)
    }

    @Test(
        "The location is the system's or a simulated one with its answers",
        arguments: SimulatedAccessCase.all
    )
    func location(accessCase: SimulatedAccessCase) {
        #expect(accessCase.access.location == accessCase.location)
    }
}
