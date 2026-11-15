//
//  PhotoLocationPlanTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreLocation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Where the photos of a flow take their location and direction from, and who asks for access")
struct PhotoLocationPlanTests {
    /// The system's location of a flow, made only when the plan asks for it, and the compasses the plan made.
    @MainActor
    final class SystemSources {
        let location = FakeLocation(authorization: .authorized)
        private(set) var locationCount = 0
        /// For each compass made, whether it follows the location.
        private(set) var compassFollows: [Bool] = []

        func makeLocation() -> any LocationAuthorizer & PhotoLocationSource {
            locationCount += 1
            return location
        }

        func makeCompass(followsLocation: Bool) -> any PhotoHeadingSource {
            compassFollows.append(followsLocation)
            return FakeHeading()
        }
    }

    private static let providedFix = CLLocation(latitude: 50.45, longitude: 30.52)

    private func makePlan(
        location: CameraFlowPhotoLocation,
        direction: CameraFlowPhotoDirection = .off,
        hasProvider: Bool = false,
        canCarryLocation: Bool = true,
        sources: SystemSources
    ) -> PhotoLocationPlan {
        var configuration = CameraFlowConfiguration()
        configuration.photoLocation = location
        configuration.photoDirection = direction
        if !canCarryLocation {
            configuration.output.metadata = .stripped
            configuration.photoLibrarySaving.isEnabled = .fixed(false)
        }
        let provider: () -> CLLocation? = { Self.providedFix }
        return PhotoLocationPlan(
            configuration: configuration,
            locationProvider: hasProvider ? provider : nil,
            makeProvidedLocation: { ProvidedPhotoLocation($0) { .precise } },
            makeSystemLocation: { sources.makeLocation() },
            makeCompass: { sources.makeCompass(followsLocation: $0) }
        )
    }

    @Test("Photos without a location make no location of the system and ask for nothing")
    func locationOff() {
        let sources = SystemSources()
        let plan = makePlan(location: .off, sources: sources)
        #expect(plan.source == nil)
        #expect(plan.authorizer == nil)
        #expect(plan.heading == nil)
        #expect(sources.locationCount == 0)
        #expect(sources.compassFollows.isEmpty)
    }

    @Test("Photos that can carry no location make no location of the system and no compass, and ask for nothing")
    func photosWithoutLocation() {
        let sources = SystemSources()
        let plan = makePlan(
            location: .automatic,
            direction: .recorded,
            hasProvider: true,
            canCarryLocation: false,
            sources: sources
        )
        #expect(plan.source == nil)
        #expect(plan.authorizer == nil)
        #expect(plan.heading == nil)
        #expect(sources.locationCount == 0)
        #expect(sources.compassFollows.isEmpty)
    }

    @Test(
        "The photos take the flow's own location, and the flow asks through it only where it asks itself",
        arguments: [(CameraFlowPhotoLocation.automatic, true), (.appRequestsAccess, false)]
    )
    func ownLocation(location: CameraFlowPhotoLocation, asks: Bool) {
        let sources = SystemSources()
        let plan = makePlan(location: location, sources: sources)
        #expect(plan.source === sources.location)
        #expect((plan.authorizer === sources.location) == asks)
        #expect((plan.authorizer != nil) == asks)
        #expect(sources.locationCount == 1)
    }

    @Test(
        "The app's provider replaces only the location of the photos, and the flow still asks where it asks itself",
        arguments: [(CameraFlowPhotoLocation.automatic, true), (.appRequestsAccess, false)]
    )
    func providedLocation(location: CameraFlowPhotoLocation, asks: Bool) {
        let sources = SystemSources()
        let plan = makePlan(location: location, hasProvider: true, sources: sources)
        #expect(plan.source !== sources.location)
        #expect(plan.source?.location == Self.providedFix)
        #expect((plan.authorizer === sources.location) == asks)
        #expect((plan.authorizer != nil) == asks)
    }

    @Test(
        "The compass is made only for photos that record the direction, and follows the location they record",
        arguments: [
            (CameraFlowPhotoLocation.automatic, CameraFlowPhotoDirection.recorded, [true]),
            (.appRequestsAccess, .recorded, [true]),
            (.off, .recorded, [false]),
            (.automatic, .off, [])
        ]
    )
    func compass(location: CameraFlowPhotoLocation, direction: CameraFlowPhotoDirection, follows: [Bool]) {
        let sources = SystemSources()
        let plan = makePlan(location: location, direction: direction, sources: sources)
        #expect(sources.compassFollows == follows)
        #expect((plan.heading != nil) == (direction == .recorded))
    }
}
