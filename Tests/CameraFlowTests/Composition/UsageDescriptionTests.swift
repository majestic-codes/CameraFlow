//
//  UsageDescriptionTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

/// The usage descriptions a flow checks in the app's Info.plist before it asks the system for a resource.
@Suite("The usage descriptions of the app")
struct UsageDescriptionTests {

    @Test(
        "Saving asks with the description of its destination",
        arguments: [
            (CameraFlowPhotoLibrarySaving.Destination.library, UsageDescription.photoLibraryAdd),
            (.album(named: "Field"), .photoLibrary)
        ]
    )
    func libraryDescription(destination: CameraFlowPhotoLibrarySaving.Destination, description: UsageDescription) {
        #expect(UsageDescription.photoLibrary(for: destination) == description)
    }

    @Test("The keys are the ones of the Info.plist", arguments: UsageDescription.allCases)
    func key(description: UsageDescription) {
        let keys: [UsageDescription: String] = [
            .camera: "NSCameraUsageDescription",
            .photoLibraryAdd: "NSPhotoLibraryAddUsageDescription",
            .photoLibrary: "NSPhotoLibraryUsageDescription",
            .locationWhenInUse: "NSLocationWhenInUseUsageDescription"
        ]
        #expect(description.rawValue == keys[description])
        #expect(description.missingMessage.contains(description.rawValue))
    }

    @Test("A description the Info.plist has passes", arguments: UsageDescription.allCases)
    func present(description: UsageDescription) {
        let info = [description.rawValue: "Why the app asks"]
        description.require { info[$0] }
    }

    #if os(macOS)
    @Test("A description the Info.plist lacks stops the program")
    func missing() async {
        await #expect(processExitsWith: .failure) {
            let info = [UsageDescription.camera.rawValue: "Why the app asks"]
            UsageDescription.locationWhenInUse.require { info[$0] }
        }
    }
    #endif
}
