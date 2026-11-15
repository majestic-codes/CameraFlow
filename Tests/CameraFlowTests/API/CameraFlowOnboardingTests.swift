//
//  CameraFlowOnboardingTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("Introduction of the flow in its configuration")
struct CameraFlowOnboardingTests {

    @Test("The default flow introduces itself when it has to, over access as the system has it")
    func defaults() {
        let configuration = CameraFlowConfiguration()
        #expect(configuration.onboarding == .automatic)
        #expect(configuration.simulatedAccess == .granted)
    }

    @Test("The app can turn the introduction off")
    func off() {
        var configuration = CameraFlowConfiguration()
        configuration.onboarding = .off
        #expect(configuration != CameraFlowConfiguration())
    }
}
