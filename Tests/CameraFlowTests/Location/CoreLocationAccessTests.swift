//
//  CoreLocationAccessTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@testable import CameraFlow

@Suite("Core Location's access in the flow's terms")
struct CoreLocationAccessTests {

    @Test(
        "Each authorization status the macOS SDK names stands for its access",
        arguments: [
            (CLAuthorizationStatus.notDetermined, LocationAuthorization.notDetermined),
            (.authorizedAlways, .authorized),
            (.denied, .denied),
            (.restricted, .restricted)
        ]
    )
    func authorization(status: CLAuthorizationStatus, authorization: LocationAuthorization) {
        #expect(LocationAuthorization(status) == authorization)
    }

    @Test("Precise Location on is the precise location, and off the approximate one")
    func precision() {
        #expect(LocationPrecision(.fullAccuracy) == .precise)
        #expect(LocationPrecision(.reducedAccuracy) == .approximate)
    }
}
