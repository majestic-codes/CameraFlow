//
//  DualCameraCaptureTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Dual camera: settings and captures with the circle on", .temporaryDirectory, .timeLimit(.minutes(1)))
struct DualCameraCaptureTests {
    let service = RecordingCameraService()

    /// A setting the pair does not offer, chosen before the circle comes on.
    struct NarrowedCase: Sendable, CustomTestStringConvertible {
        let name: String
        let state: CameraFlowInitialState
        let notice: DualCameraNotice?
        let format: CameraFlowPhotoFormat
        let isLivePhotoEnabled: Bool

        var testDescription: String {
            name
        }
    }

    nonisolated static let narrowedCases: [NarrowedCase] = {
        var live = DualCameraFixture.keptState
        live.isLivePhotoEnabled = CameraFlowSetting(true)
        var raw = DualCameraFixture.keptState
        raw.photoFormat.value = .raw
        var flash = DualCameraFixture.keptState
        flash.flashMode.value = .alwaysOn
        return [
            NarrowedCase(
                name: "everything kept",
                state: DualCameraFixture.keptState,
                notice: nil,
                format: .heif,
                isLivePhotoEnabled: false
            ),
            NarrowedCase(
                name: "Live Photo",
                state: live,
                notice: .settingOff(.livePhoto),
                format: .heif,
                isLivePhotoEnabled: false
            ),
            NarrowedCase(
                name: "RAW",
                state: raw,
                notice: .settingOff(.raw),
                format: .heif,
                isLivePhotoEnabled: false
            ),
            NarrowedCase(
                name: "flash on, which the pair keeps",
                state: flash,
                notice: nil,
                format: .heif,
                isLivePhotoEnabled: false
            )
        ]
    }()

    private func makeModel(
        initialState: CameraFlowInitialState,
        onCapture: @escaping (CameraCapture) -> Void = { _ in }
    ) -> PhotoCameraModel {
        let model = makeCaptureModel(
            service: service,
            initialState: initialState,
            isDualCameraOffered: true,
            onCapture: onCapture
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    @Test(
        "A chosen setting the pair does not offer stays chosen, is left out of the photo and named in the notice",
        arguments: narrowedCases
    )
    func narrowed(narrowedCase: NarrowedCase) async throws {
        var captures: [CameraCapture] = []
        let model = makeModel(initialState: narrowedCase.state) { captures.append($0) }
        await model.start()
        await model.toggleDualCamera()
        #expect(model.notices.dualCameraNotice == narrowedCase.notice)
        #expect(model.settings.photoFormat == narrowedCase.state.photoFormat.value)
        #expect(model.settings.isLivePhotoEnabled == narrowedCase.state.isLivePhotoEnabled.value)
        #expect(model.settings.effectivePhotoFormat == narrowedCase.format)
        #expect(model.settings.isLivePhotoInEffect == narrowedCase.isLivePhotoEnabled)
        await model.capture()
        let request = try #require(service.captureRequests.last)
        #expect(request.format == narrowedCase.format)
        #expect(request.isLivePhotoEnabled == narrowedCase.isLivePhotoEnabled)
        #expect(request.resolution.isPreferred)
        #expect(request.flashMode == narrowedCase.state.flashMode.value)
        #expect(model.notices.dualCameraNotice == nil)
        for capture in captures {
            try CaptureTestSupport.discardFiles(of: capture)
        }
    }

    @Test("The settings left out come back with the circle off")
    func comeBack() async throws {
        var state = DualCameraFixture.keptState
        state.photoFormat.value = .raw
        let model = makeModel(initialState: state)
        await model.start()
        await model.toggleDualCamera()
        #expect(model.settings.effectivePhotoFormat == .heif)
        #expect(model.settings.offeredPhotoFormats == [.heif])
        await model.toggleDualCamera()
        #expect(model.settings.effectivePhotoFormat == .raw)
        #expect(model.settings.offeredPhotoFormats == [.heif, .raw])
    }

    @Test("A pair without a flash takes every photo without it and dims the Flash indicator")
    func noFlash() async throws {
        let service = RecordingCameraService(dualPhotoCapabilities: CaptureTestSupport.dualWithoutFlash)
        var state = DualCameraFixture.keptState
        state.flashMode.value = .alwaysOn
        let model = makeCaptureModel(service: service, initialState: state, isDualCameraOffered: true)
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        await model.start()
        #expect(model.settings.isFlashSelectable)
        await model.toggleDualCamera()
        #expect(model.notices.dualCameraNotice == .settingOff(.flash))
        #expect(model.settings.isFlashSelectable == false)
        #expect(model.settings.effectiveFlashMode == .off)
        #expect(model.settings.flashMode == .alwaysOn)
    }

    @Test("A photo with the circle on keeps the camera's file and comes with the copy that has the circle")
    func capture() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel(initialState: DualCameraFixture.keptState) { captures.append($0) }
        await model.start()
        await model.toggleDualCamera()
        await model.capture()
        let capture = try #require(captures.first)
        let copyURL = try #require(capture.dualCameraCopy?.url)
        let fileName = capture.fileURL.deletingPathExtension().lastPathComponent
        #expect(copyURL.lastPathComponent.hasPrefix(fileName + "-dual-"))
        let copy = try PixelGrid(fileAt: copyURL)
        let size = CGSize(width: copy.width, height: copy.height)
        #expect(try capture.uprightPixelSize() == size)
        let square = DualCameraPlacement.circleRectangle(
            region: DualCameraFixture.circleOnScreen.region,
            quarterTurns: 0,
            isViewfinderMirrored: false,
            framedRegion: nil,
            photoSize: size
        )
        let inside = try copy[Int(square.midX), Int(square.midY + square.height / 4)]
        let front = PixelGrid.Pixel(red: 242, green: 140, blue: 51)
        #expect(inside.isClose(to: front), "The circle shows \(inside)")
        // The stem of the simulated front camera's letter shows on its leading side, as taken: no photo is mirrored.
        let stem = try Self.pixel(of: copy, in: square, at: CGPoint(x: 0.26, y: 0.5))
        let trailing = try Self.pixel(of: copy, in: square, at: CGPoint(x: 0.74, y: 0.5))
        #expect(stem.isClose(to: Self.white), "The stem is \(stem)")
        #expect(trailing.isClose(to: front), "Beside the stem is \(trailing)")
        let outside = try copy[Int(square.minX) - 4, Int(square.maxY) + 4]
        #expect(outside.isClose(to: PixelGrid.Pixel(red: 0, green: 0, blue: 0)), "Beside the circle is \(outside)")
        let thumbnail = try PixelGrid(capture.thumbnail)
        let thumbnailSquare = DualCameraPlacement.circleRectangle(
            region: DualCameraFixture.circleOnScreen.region,
            quarterTurns: 0,
            isViewfinderMirrored: false,
            framedRegion: nil,
            photoSize: CGSize(width: thumbnail.width, height: thumbnail.height)
        )
        let thumbnailRow = Int(thumbnailSquare.midY + thumbnailSquare.height / 4)
        let thumbnailInside = try thumbnail[Int(thumbnailSquare.midX), thumbnailRow]
        #expect(thumbnailInside.isClose(to: front), "The thumbnail's circle shows \(thumbnailInside)")
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("After a swap the original is the front camera's photo as taken, the circle at the mirrored place")
    func swappedCapture() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel(initialState: DualCameraFixture.keptState) { captures.append($0) }
        await model.start()
        await model.toggleDualCamera()
        await model.flipCamera()
        await model.capture()
        let capture = try #require(captures.first)
        let copyURL = try #require(capture.dualCameraCopy?.url)
        let copy = try PixelGrid(fileAt: copyURL)
        let photo = CGRect(x: 0, y: 0, width: copy.width, height: copy.height)
        let front = PixelGrid.Pixel(red: 242, green: 140, blue: 51)
        // The main photo shows the front camera's letter as taken, where the viewfinder showed it mirrored.
        #expect(try Self.pixel(of: copy, in: photo, at: CGPoint(x: 0.26, y: 0.5)).isClose(to: Self.white))
        #expect(try Self.pixel(of: copy, in: photo, at: CGPoint(x: 0.74, y: 0.5)).isClose(to: front))
        let square = DualCameraPlacement.circleRectangle(
            region: DualCameraFixture.circleOnScreen.region,
            quarterTurns: 0,
            isViewfinderMirrored: true,
            framedRegion: nil,
            photoSize: photo.size
        )
        // The circle shows the back camera's letter as taken: black scene, the stem on the leading side.
        let stem = try Self.pixel(of: copy, in: square, at: CGPoint(x: 0.26, y: 0.5))
        let trailing = try Self.pixel(of: copy, in: square, at: CGPoint(x: 0.74, y: 0.5))
        #expect(stem.isClose(to: Self.white), "The stem is \(stem)")
        #expect(trailing.isClose(to: PixelGrid.Pixel(red: 0, green: 0, blue: 0)), "Beside the stem is \(trailing)")
        try CaptureTestSupport.discardFiles(of: capture)
    }

    private static let white = PixelGrid.Pixel(red: 255, green: 255, blue: 255)

    /// The pixel at a unit point of a rectangle of the picture.
    private static func pixel(of pixels: PixelGrid, in rectangle: CGRect, at point: CGPoint) throws -> PixelGrid.Pixel {
        let column = Int(rectangle.minX + rectangle.width * point.x)
        let row = Int(rectangle.minY + rectangle.height * point.y)
        return try pixels[column, row]
    }

    @Test("A photo without the circle on has no copy")
    func captureWithoutCircle() async throws {
        var captures: [CameraCapture] = []
        let model = makeModel(initialState: DualCameraFixture.keptState) { captures.append($0) }
        await model.start()
        await model.capture()
        let capture = try #require(captures.first)
        #expect(capture.dualCameraCopy == nil)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A dual photo without the place of the circle is handed over without the copy and says so")
    func captureWithoutPlace() async throws {
        let files = CaptureTestSupport.makeFileStore()
        var captures: [CameraCapture] = []
        let model = makeCaptureModel(
            service: service,
            initialState: DualCameraFixture.keptState,
            isDualCameraOffered: true,
            files: files
        ) { captures.append($0) }
        await model.start()
        await model.toggleDualCamera()
        await model.capture()
        let capture = try #require(captures.first)
        #expect(capture.dualCameraCopy == nil)
        #expect(capture.losses == [.circleCameraFrame])
        #expect(model.notices.captureError == nil)
        #expect(model.notices.captureLoss == .circleCameraFrame)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
