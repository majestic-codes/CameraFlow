//
//  SimulatedLocationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@MainActor
@Suite("The simulated location")
struct SimulatedLocationTests {

    @Test("The simulated location answers at once as it was told, and knows no location")
    func simulated() async {
        let unasked = SimulatedLocation(authorization: .notDetermined)
        #expect(await unasked.requestAuthorization() == .authorized)
        #expect(unasked.authorization == .authorized)
        let refusing = SimulatedLocation(authorization: .notDetermined, answerOnRequest: .denied)
        #expect(await refusing.requestAuthorization() == .denied)
        #expect(await refusing.requestAuthorization() == .denied)
        let granted = SimulatedLocation(authorization: .authorized, answerOnRequest: .denied)
        #expect(await granted.requestAuthorization() == .authorized)
        granted.start()
        #expect(granted.location == nil)
    }
}
