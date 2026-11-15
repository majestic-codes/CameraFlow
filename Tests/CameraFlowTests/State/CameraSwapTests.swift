//
//  CameraSwapTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import QuartzCore
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Camera swap: the pictures after a switch and the cover over them", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraSwapTests {
    let service = RecordingCameraService()

    private static let backColor = PixelGrid.Pixel(red: 0, green: 0, blue: 0)
    private static let frontColor = PixelGrid.Pixel(red: 242, green: 140, blue: 51)
    private static let letterColor = PixelGrid.Pixel(red: 255, green: 255, blue: 255)

    private func makeModel() -> PhotoCameraModel {
        let model = makeCaptureModel(
            service: service,
            initialState: DualCameraFixture.keptState,
            isDualCameraOffered: true
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    /// The picture a preview shows, drawn at the size of the simulated picture.
    private func picture(of preview: any CameraPreview) throws -> PixelGrid {
        let size = CGSize(width: 60, height: 80)
        preview.layer.frame = CGRect(origin: .zero, size: size)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        preview.layer.render(in: context)
        let image = try #require(context.makeImage())
        return try PixelGrid(image)
    }

    /// Checks that a preview shows the camera at a position: its colour, and the stem of its letter on the
    /// leading side for the back camera and on the trailing side for the mirrored front one.
    private func expectPicture(of preview: any CameraPreview, shows position: CameraPosition) throws {
        let grid = try picture(of: preview)
        let background = position == .back ? Self.backColor : Self.frontColor
        let stemColumn = position == .back ? 15 : 44
        let emptyColumn = position == .back ? 44 : 15
        #expect(try grid[stemColumn, 40].isClose(to: Self.letterColor), "The letter of the \(position) camera")
        #expect(try grid[emptyColumn, 40].isClose(to: background), "The colour of the \(position) camera")
    }

    @Test("After any number of swaps the viewfinder shows the main camera and the circle the other", arguments: 1...6)
    func picturesAfterSwaps(count: Int) async throws {
        let model = makeModel()
        let viewfinder = model.session.makePreview()
        await model.start()
        await model.toggleDualCamera()
        let circle = model.session.makeCirclePreview()
        let backLenses = model.zoom.lenses
        for _ in 0..<count {
            await model.flipCamera()
        }
        let main: CameraPosition = count.isMultiple(of: 2) ? .back : .front
        #expect(model.dualCamera.isOn)
        #expect(model.session.position == main)
        #expect(model.dualCamera.circlePosition == main.flipped)
        #expect(model.zoom.lenses == (main == .back ? backLenses : [CameraLens(factor: 1, focalLength: nil)]))
        #expect(model.zoom.factor == 1)
        #expect(model.session.failure == nil)
        try expectPicture(of: viewfinder, shows: main)
        try expectPicture(of: circle, shows: main.flipped)
    }

    @Test("The lenses change with the camera of the viewfinder in one step, never to another set in between")
    func lensesChangeOnce() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        let backFactors = model.zoom.lenses.map(\.factor)
        service.holdsCalls = true
        let swap = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        #expect(model.zoom.lenses.map(\.factor) == backFactors)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await swap.value
        #expect(model.zoom.lenses.map(\.factor) == [1])
        #expect(model.zoom.activeLensIndex == 0)
    }

    @Test("Rapid taps on the switch button swap the pair once for each swap that finished")
    func rapidTaps() async {
        let model = makeModel()
        await model.start()
        await model.toggleDualCamera()
        let turnedOn = service.calls.count
        service.holdsCalls = true
        let taps = (0..<5).map { _ in Task { await model.flipCamera() } }
        await settle { service.heldCallCount == 1 }
        await settleQueuedWork()
        #expect(service.heldCallCount == 1)
        service.holdsCalls = false
        service.releaseHeldCalls()
        for tap in taps {
            await tap.value
        }
        let starts = service.calls.dropFirst(turnedOn).filter { $0 != .exposureBias(0) }
        #expect(starts == [.startDualCamera(main: .front)])
        #expect(model.session.position == .front)
        await model.flipCamera()
        #expect(service.calls.suffix(2) == [.startDualCamera(main: .back), .exposureBias(0)])
        #expect(model.session.position == .back)
    }

    @Test("The first start covers nothing: there is no picture yet")
    func firstStart() async {
        let model = makeModel()
        let cover = RecordingPictureCover(countingCallsOf: service)
        model.session.pictureCovers.add(cover)
        await model.start()
        #expect(cover.events.isEmpty)
    }

    @Test("Every switch covers the pictures before the camera is asked and uncovers them after it answered")
    func coverAroundSwitch() async {
        let model = makeModel()
        let viewfinder = RecordingPictureCover(countingCallsOf: service)
        model.session.pictureCovers.add(viewfinder)
        await model.start()
        let started = service.calls.count
        await model.toggleDualCamera()
        let turnedOn = service.calls.count
        #expect(viewfinder.events == [.covered(afterCalls: started), .uncovered(afterCalls: started + 1)])
        let circle = RecordingPictureCover(countingCallsOf: service)
        model.dualCamera.pictureCovers.add(circle)
        await model.flipCamera()
        #expect(circle.events == [.covered(afterCalls: turnedOn), .uncovered(afterCalls: turnedOn + 1)])
        #expect(viewfinder.events.suffix(2) == circle.events)
        let swapped = service.calls.count
        await model.flipCamera()
        #expect(circle.events.suffix(2) == [.covered(afterCalls: swapped), .uncovered(afterCalls: swapped + 1)])
        #expect(viewfinder.isCovered == false)
    }

    @Test("The pictures stay covered for as long as the switch is under way")
    func coveredWhileSwitching() async {
        let model = makeModel()
        let cover = RecordingPictureCover(countingCallsOf: service)
        model.session.pictureCovers.add(cover)
        await model.start()
        service.holdsCalls = true
        let flip = Task { await model.flipCamera() }
        await settle { service.heldCallCount == 1 }
        #expect(cover.isCovered)
        service.holdsCalls = false
        service.releaseHeldCalls()
        await flip.value
        #expect(cover.isCovered == false)
    }

    @Test("A switch that fails leaves the pictures uncovered")
    func uncoveredAfterFailure() async {
        let model = makeModel()
        let cover = RecordingPictureCover(countingCallsOf: service)
        model.session.pictureCovers.add(cover)
        await model.start()
        service.dualStartError = .dualCameraUnavailable("No pair of formats fits")
        await model.toggleDualCamera()
        #expect(model.dualCamera.isOn == false)
        #expect(cover.isCovered == false)
        service.startError = .cannotUseCamera("The session refused the camera input")
        await model.flipCamera()
        #expect(cover.isCovered == false)
        #expect(cover.events.count.isMultiple(of: 2))
    }

    @Test("A cover that is gone is not kept")
    func releasedCover() async {
        let model = makeModel()
        await model.start()
        weak var released: RecordingPictureCover?
        do {
            let cover = RecordingPictureCover(countingCallsOf: service)
            model.session.pictureCovers.add(cover)
            released = cover
        }
        #expect(released == nil)
        await model.flipCamera()
        #expect(model.session.position == .front)
    }
}
