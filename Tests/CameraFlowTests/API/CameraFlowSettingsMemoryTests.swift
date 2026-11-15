//
//  CameraFlowSettingsMemoryTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Where the flow remembers the camera choices", .timeLimit(.minutes(1)))
struct CameraFlowSettingsMemoryTests {

    @Test("A flow that forgets opens no defaults")
    func off() throws {
        #expect(try CameraFlowSettingsMemory.off.openDefaults() == nil)
        CameraFlowSettingsMemory.off.validate()
    }

    @Test("Without a suite the memory is the standard defaults")
    func standard() throws {
        #expect(try CameraFlowSettingsMemory.userDefaults().openDefaults() === UserDefaults.standard)
        CameraFlowConfiguration().validate()
    }

    @Test("A named suite is opened as that suite, never as the standard defaults")
    func suite() throws {
        let suiteName = "CameraFlowTests.settingsMemory.\(UUID().uuidString)"
        let memory = CameraFlowSettingsMemory.userDefaults(suiteName: suiteName)
        let defaults = try #require(try memory.openDefaults())
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(defaults !== UserDefaults.standard)
        defaults.set(Data([1]), forKey: "CameraFlowTests.marker")
        #expect(UserDefaults.standard.data(forKey: "CameraFlowTests.marker") == nil)
        memory.validate()
    }

    @Test(
        "A suite the defaults cannot open is refused by name, with no fallback to the standard defaults",
        arguments: ["", UserDefaults.globalDomain]
    )
    func unusableSuite(suiteName: String) {
        let memory = CameraFlowSettingsMemory.userDefaults(suiteName: suiteName)
        let refusal = CameraFlowSettingsMemory.UnusableSuite(suiteName: suiteName)
        #expect(throws: refusal) {
            try memory.openDefaults()
        }
        #expect(refusal.message.contains("\"\(suiteName)\""))
    }

    #if os(macOS)
    @Test("A configuration with a suite the defaults cannot open stops the program")
    func invalidConfiguration() async {
        await #expect(processExitsWith: .failure) {
            var configuration = CameraFlowConfiguration()
            configuration.settingsMemory = .userDefaults(suiteName: UserDefaults.globalDomain)
            configuration.validate()
        }
    }
    #endif
}
