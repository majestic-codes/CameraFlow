//
//  ZoomLensChangeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Testing
@testable import CameraFlow

/// The zoom reports when it crosses into another lens, whatever moved it, which ends the AE/AF Lock.
@MainActor
@Suite("Lens changes the zoom reports")
struct ZoomLensChangeTests {
    /// The lens changes the zoom reported, one entry for each, with the lens it crossed into.
    @MainActor
    final class LensChanges {
        var lenses: [Int?] = []
    }

    private let service = RecordingCameraService()
    private let changes = LensChanges()

    /// The zoom over the started back camera, recording the lens changes it reports from then on.
    private func makeStartedZoom() async throws -> ZoomModel {
        let zoom = ZoomModel(service: service, haptics: RecordingCameraHaptics())
        zoom.cameraStarted(try await service.start(position: .back))
        zoom.onLensChange = { [changes, weak zoom] in changes.lenses.append(zoom?.activeLensIndex) }
        return zoom
    }

    @Test("A lens button, the dial and the Camera Control report a new lens, and the same lens is no change")
    func reportedChanges() async throws {
        let zoom = try await makeStartedZoom()
        let wide = try #require(zoom.lenses.firstIndex { $0.factor < 1 })
        let main = try #require(zoom.activeLensIndex)
        zoom.selectLens(at: wide)
        zoom.selectLens(at: wide)
        #expect(changes.lenses == [wide])
        zoom.turnDial(to: zoom.lenses[main].factor)
        zoom.factorChanged(to: zoom.lenses[wide].factor)
        #expect(changes.lenses == [wide, main, wide])
    }

    @Test("A zoom within a lens reports nothing")
    func zoomWithinTheLens() async throws {
        let zoom = try await makeStartedZoom()
        let lens = try #require(zoom.activeLensIndex)
        let next = try #require(zoom.lenses.dropFirst(lens + 1).first)
        zoom.setZoom((zoom.lenses[lens].factor + next.factor) / 2)
        #expect(changes.lenses.isEmpty)
    }
}
