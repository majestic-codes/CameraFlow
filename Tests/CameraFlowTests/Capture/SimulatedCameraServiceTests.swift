//
//  SimulatedCameraServiceTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("Simulated camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct SimulatedCameraServiceTests {

    private func request(for capabilities: PhotoCaptureCapabilities) throws -> PhotoCaptureRequest {
        let resolution = try #require(capabilities.resolution)
        return try PhotoCaptureRequest(
            flashMode: .off,
            isLivePhotoEnabled: false,
            format: .heif,
            resolution: resolution,
            capabilities: capabilities
        )
    }

    /// A photo of the running camera, asked for with what the camera offers.
    private func takePhoto(with service: SimulatedCameraService) async throws -> CapturedPhoto {
        let capabilities = try #require(service.photoCapabilities)
        let photoRequest = try request(for: capabilities)
        return try await service.capturePhoto(photoRequest)
    }

    private func storedPixels(of photo: CapturedPhoto) throws -> PixelGrid {
        let source = try #require(CGImageSourceCreateWithData(photo.imageData as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return try PixelGrid(image)
    }

    @Test("A camera that has not started takes no photo")
    func notRunning() async throws {
        let service = SimulatedCameraService(scene: .black)
        let request = try request(for: SimulatedCameraService.iPhoneBackPhotoCapabilities)
        await #expect(throws: CameraServiceError.notRunning) {
            _ = try await service.capturePhoto(request)
        }
    }

    @Test("A stopped camera takes no photo, and one started again does")
    func stopped() async throws {
        let service = SimulatedCameraService(scene: .black)
        _ = try await service.start(position: .back)
        let capabilities = try #require(service.photoCapabilities)
        let request = try request(for: capabilities)
        service.stop()
        await #expect(throws: CameraServiceError.notRunning) {
            _ = try await service.capturePhoto(request)
        }
        _ = try await service.start(position: .back)
        _ = try await service.capturePhoto(request)
    }

    @Test("The photo is shaped like the device's: EXIF, TIFF, maker notes, Display P3 and a gain map, without GPS")
    func deviceShapedPhoto() async throws {
        let service = SimulatedCameraService(scene: .color(red: 0.8, green: 0.4, blue: 0.2))
        _ = try await service.start(position: .back)
        let photo = try await takePhoto(with: service)
        let properties = try DevicePhotoFixture.properties(of: photo.imageData)
        #expect(properties[kCGImagePropertyOrientation] as? Int == 6)
        #expect(properties[kCGImagePropertyProfileName] as? String == "Display P3")
        let exif = try #require(properties[kCGImagePropertyExifDictionary] as? [CFString: Any])
        #expect(exif[kCGImagePropertyExifPixelXDimension] as? Int == properties[kCGImagePropertyPixelWidth] as? Int)
        #expect(exif[kCGImagePropertyExifLensModel] as? String == "CameraFlow simulated back camera")
        #expect(properties[kCGImagePropertyTIFFDictionary] != nil)
        #expect(properties[kCGImagePropertyMakerAppleDictionary] != nil)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(try DevicePhotoFixture.gainMap(of: photo.imageData).hasVersionTag)
    }

    @Test("A Live Photo movie goes into the package's directory of movies under the camera's temporary directory")
    func movieDirectory() async throws {
        let service = SimulatedCameraService(scene: .black)
        service.temporaryDirectory = TestDirectory.current
        _ = try await service.start(position: .back)
        let capabilities = try #require(service.photoCapabilities)
        let resolution = try #require(capabilities.resolution)
        let request = try PhotoCaptureRequest(
            flashMode: .off,
            isLivePhotoEnabled: true,
            format: .heif,
            resolution: resolution,
            capabilities: capabilities
        )
        let photo = try await service.capturePhoto(request)
        let movieURL = try #require(photo.livePhotoMovieURL)
        let root = TestDirectory.current.appendingPathComponent("CameraFlow", isDirectory: true)
        #expect(movieURL.path.hasPrefix(root.path))
        #expect(FileManager.default.fileExists(atPath: movieURL.path))
    }

    @Test("A device without a dual camera says so, and the camera that ran keeps its capabilities")
    func noDualCamera() async throws {
        let service = SimulatedCameraService(scene: .black, isDualCameraSupported: false)
        _ = try await service.start(position: .back)
        let failure = CameraServiceError.dualCameraUnavailable("The simulated device has no dual camera")
        await #expect(throws: failure) {
            _ = try await service.startDualCamera(main: .back)
        }
        #expect(service.photoCapabilities == SimulatedCameraService.iPhoneBackPhotoCapabilities)
    }

    @Test("The scene colour fills the photo and the preview")
    func colouredScene() async throws {
        let service = SimulatedCameraService(scene: .color(red: 0.8, green: 0.4, blue: 0.2))
        let preview = service.makePreview()
        _ = try await service.start(position: .back)
        let photo = try await takePhoto(with: service)
        let pixels = try storedPixels(of: photo)
        let scene = PixelGrid.Pixel(red: 204, green: 102, blue: 51)
        #expect(try pixels[0, 0].isClose(to: scene))
        #expect(try pixels[pixels.width - 1, pixels.height - 1].isClose(to: scene))
        let components = try #require(preview.layer.backgroundColor?.components)
        try #require(components.count == 4)
        expectClose(components[0], 0.8, tolerance: 0.001)
        expectClose(components[1], 0.4, tolerance: 0.001)
        expectClose(components[2], 0.2, tolerance: 0.001)
        #expect(preview.layer.contents == nil)
    }

    @Test("Zoom, focus, exposure and Camera Control change nothing in the flat photo")
    func flatAtEveryZoom() async throws {
        let service = SimulatedCameraService(scene: .color(red: 0.1, green: 0.5, blue: 0.9))
        _ = try await service.start(position: .back)
        let capabilities = try #require(service.photoCapabilities)
        let photoRequest = try request(for: capabilities)
        let before = try await service.capturePhoto(photoRequest)
        service.setZoom(8)
        service.rampZoom(to: 2, rate: 4)
        service.focus(atDevicePoint: CGPoint(x: 0.2, y: 0.7))
        service.setExposureBias(1.5)
        service.selectCaptureControlLens(at: 2)
        let after = try await service.capturePhoto(photoRequest)
        #expect(after.imageData == before.imageData)
        #expect(service.photoCapabilities == capabilities)
    }

    @Test("A camera told to fail its first starts fails that many times, then starts")
    func startFailures() async throws {
        let service = SimulatedCameraService(scene: .black, startFailureCount: 2)
        let failure = CameraServiceError.cannotUseCamera("The simulated camera does not start")
        for _ in 0..<2 {
            await #expect(throws: failure) {
                _ = try await service.start(position: .back)
            }
            #expect(service.photoCapabilities == nil)
        }
        let capabilities = try await service.start(position: .back)
        #expect(capabilities.position == .back)
        #expect(service.photoCapabilities == SimulatedCameraService.iPhoneBackPhotoCapabilities)
    }

    @Test("A flow over a camera that fails its first start shows a failure to retry from, and the retry runs it")
    func retryAfterFailedStart() async {
        let service = SimulatedCameraService(scene: .black, startFailureCount: 1)
        let model = PhotoCameraModel(
            service: service,
            haptics: RecordingCameraHaptics(),
            attitudeSensor: ManualAttitudeSensor(),
            initialState: CameraFlowInitialState(),
            clock: ManualClock(),
            files: CaptureTestSupport.makeFileStore()
        ) { _ in }
        await model.start()
        let failure = CameraFailure.unavailable(.cannotUseCamera("The simulated camera does not start"))
        #expect(model.session.failure == failure)
        #expect(model.session.failure?.isRetryable == true)
        #expect(model.session.capabilities == nil)
        await model.retry()
        #expect(model.session.failure == nil)
        #expect(model.session.capabilities?.position == .back)
    }

    @Test("The front camera alone shows the scene with a letter, mirrored on screen and as taken in its photo")
    func frontCamera() async throws {
        let service = SimulatedCameraService(scene: .color(red: 0.1, green: 0.5, blue: 0.9))
        let preview = service.makePreview()
        _ = try await service.start(position: .front)
        let photo = try await takePhoto(with: service)
        let uprightImage = try Self.uprightImage(of: photo)
        let upright = try PixelGrid(uprightImage)
        let scene = PixelGrid.Pixel(red: 26, green: 128, blue: 230)
        let letter = PixelGrid.Pixel(red: 255, green: 255, blue: 255)
        let row = upright.height / 2
        // The stem of the letter, on the leading side as the camera saw it.
        #expect(try upright[upright.width * 26 / 100, row].isClose(to: letter))
        #expect(try upright[upright.width * 74 / 100, row].isClose(to: scene))
        let shown = try Self.picture(of: preview)
        #expect(try shown[shown.width * 74 / 100, shown.height / 2].isClose(to: letter))
        #expect(try shown[shown.width * 26 / 100, shown.height / 2].isClose(to: scene))
    }

    @Test("The front camera in the viewfinder of the pair takes its photo as taken, like the front camera alone")
    func frontCameraOfThePair() async throws {
        let service = SimulatedCameraService(scene: .black)
        _ = try await service.startDualCamera(main: .front)
        let photo = try await takePhoto(with: service)
        let uprightImage = try Self.uprightImage(of: photo)
        let upright = try PixelGrid(uprightImage)
        let row = upright.height / 2
        let white = PixelGrid.Pixel(red: 255, green: 255, blue: 255)
        let front = PixelGrid.Pixel(red: 242, green: 140, blue: 51)
        #expect(try upright[upright.width * 26 / 100, row].isClose(to: white))
        #expect(try upright[upright.width * 74 / 100, row].isClose(to: front))
        #expect(try #require(photo.circleCameraFrame).isViewfinderMirrored)
    }

    /// The picture a preview shows, drawn at the size of the simulated picture.
    private static func picture(of preview: any CameraPreview) throws -> PixelGrid {
        let width = 60
        let height = 80
        preview.layer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
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

    /// The photo upright, turned by its orientation.
    private static func uprightImage(of photo: CapturedPhoto) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(photo.imageData as CFData, nil))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256
        ]
        return try #require(CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary))
    }

    @Test("The simulated camera is granted from the start, or when it is asked for")
    func simulatedCamera() async {
        #expect(SimulatedCameraService(scene: .black).isAuthorizationDetermined)
        let service = SimulatedCameraService(scene: .black, isAuthorizationDetermined: false)
        #expect(service.isAuthorizationDetermined == false)
        #expect(await service.requestAuthorization() == .authorized)
        #expect(service.isAuthorizationDetermined)
    }

    @Test("A point of the simulated preview is its own device point")
    func previewPoint() {
        let preview = SimulatedPreview(color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        let point = CGPoint(x: 0.25, y: 0.75)
        #expect(preview.devicePoint(atLayerPoint: point) == point)
    }

    @Test(
        "The simulated attitude is the fixed orientation, reported once at the start",
        arguments: [CameraOrientation.portrait, .landscapeLeft, .landscapeRight, .upsideDown]
    )
    func attitude(orientation: CameraOrientation) {
        let sensor = SimulatedAttitudeSensor(orientation: orientation)
        var readings: [DeviceGravity] = []
        sensor.start { readings.append($0) }
        sensor.stop()
        #expect(readings == [.upright(in: orientation)])
    }
}
