//
//  PhotoSizeEstimateTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@Suite("The approximate size of a photo", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSizeEstimateTests {
    private static let twelveMegapixels = CGSize(width: 4032, height: 3024)
    private static let twentyFourMegapixels = CGSize(width: 5712, height: 4284)

    private func estimate(
        cameraFrame: CGSize = twelveMegapixels,
        aspectRatio: CameraFlowAspectRatio = .fourByThree,
        format: CameraFlowPhotoFormat = .heif,
        encodesHEVC: Bool = true,
        quality: CameraFlowQuality = .high,
        appOutput: CameraFlowOutput = CameraFlowOutput()
    ) -> PhotoSizeEstimate {
        PhotoSizeEstimate(
            cameraFrame: cameraFrame,
            aspectRatio: aspectRatio,
            format: format,
            encodesHEVC: encodesHEVC,
            output: quality.output(within: appOutput)
        )
    }

    // MARK: - The frame

    @Test(
        "The pixels are those of the camera's frame, cut to the aspect ratio and scaled to the size limit",
        arguments: [
            (CameraFlowAspectRatio.fourByThree, CameraFlowQuality.high, 12_192_768),
            (.sixteenByNine, .high, 9_144_576),
            (.square, .high, 9_144_576),
            (.fourByThree, .medium, 2_764_800),
            (.sixteenByNine, .medium, 2_073_600),
            (.square, .low, 3_686_400)
        ]
    )
    func pixelCount(aspectRatio: CameraFlowAspectRatio, quality: CameraFlowQuality, expected: Int) {
        let pixels = estimate(aspectRatio: aspectRatio, quality: quality).pixelCount
        expectClose(pixels, Double(expected), tolerance: 1)
    }

    @Test("A RAW photo is the whole frame of the camera, whatever the aspect ratio")
    func rawFrame() {
        let raw = estimate(aspectRatio: .square, format: .raw)
        #expect(raw.pixelCount == 12_192_768)
        #expect(raw.bytesPerPixel == PhotoSizeEstimate.CameraBytesPerPixel.appleProRAW)
    }

    // MARK: - Bytes per pixel

    @Test("An untouched photo takes what the camera writes: HEIF, or JPEG on a camera without HEVC")
    func cameraFile() {
        #expect(estimate().bytesPerPixel == 0.17)
        #expect(estimate(encodesHEVC: false).bytesPerPixel == 0.35)
        #expect(estimate(cameraFrame: Self.twentyFourMegapixels).bytesPerPixel == 0.17)
    }

    @Test("A cropped photo is encoded again at the cropper's quality, in the camera's format")
    func cropped() {
        expectClose(estimate(aspectRatio: .sixteenByNine).bytesPerPixel, 0.205, tolerance: 0.000_001)
        expectClose(estimate(aspectRatio: .square, encodesHEVC: false).bytesPerPixel, 0.29, tolerance: 0.000_001)
    }

    @Test("A scaled photo takes more bytes per pixel than the same encoding at the camera's size")
    func scaled() {
        expectClose(estimate(quality: .medium).bytesPerPixel, 0.205 * 1.3, tolerance: 0.000_001)
        expectClose(estimate(quality: .low).bytesPerPixel, 0.065 * 1.3, tolerance: 0.000_001)
    }

    @Test("A format of the output is taken at its quality, between the measured ones along a line")
    func outputFormat() {
        var output = CameraFlowOutput()
        output.format = .jpeg(quality: 0.8)
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.23, tolerance: 0.000_001)
        output.format = .jpeg(quality: 0.75)
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.2125, tolerance: 0.000_001)
        output.format = .heic(quality: 0.6)
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.105, tolerance: 0.000_001)
        output.format = .heic(quality: 0)
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.01, tolerance: 0.000_001)
        output.format = .jpeg(quality: 1)
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.53, tolerance: 0.000_001)
    }

    @Test("Stripped metadata means a new encoding of the whole frame")
    func stripped() {
        var output = CameraFlowOutput()
        output.metadata = .stripped
        expectClose(estimate(appOutput: output).bytesPerPixel, 0.205, tolerance: 0.000_001)
    }

    // MARK: - The size

    @Test("The sizes of the default flow: about 2.1 MB, 740 kB and 230 kB for a 12 MP photo")
    func defaultSizes() {
        #expect(estimate().byteCount == 2_072_771)
        #expect(estimate(quality: .medium).byteCount == 736_819)
        #expect(estimate(quality: .low).byteCount == 233_626)
        #expect(estimate(cameraFrame: Self.twentyFourMegapixels).byteCount == 4_159_935)
        #expect(estimate(format: .raw).byteCount == 25_604_813)
    }

    @Test(
        "A lower quality never gives a larger estimate",
        arguments: CameraFlowAspectRatio.allCases, [true, false]
    )
    func ordered(aspectRatio: CameraFlowAspectRatio, encodesHEVC: Bool) {
        let sizes = CameraFlowQuality.allCases.map {
            estimate(aspectRatio: aspectRatio, encodesHEVC: encodesHEVC, quality: $0).byteCount
        }
        #expect(sizes[1] < sizes[0])
        #expect(sizes[2] < sizes[1])
    }

    // MARK: - From the settings

    @MainActor
    @Test("The size estimate counts the pixels the camera really delivers")
    func sizeEstimate() async throws {
        let capabilities = PhotoCaptureCapabilities(
            flashModes: [.off],
            isLivePhotoSupported: false,
            exposureBiasRange: -8...8,
            formats: [.heif],
            encodesHEVC: true,
            resolution: PhotoCaptureResolution.offered(among: [(3264, 2448)]),
            lockableAdjustments: .focusAndExposure
        )
        let service = RecordingCameraService(backPhotoCapabilities: capabilities)
        let model = makeCaptureModel(service: service)
        await model.start()
        let estimate = try #require(PhotoSizeEstimate(settings: model.settings))
        #expect(estimate.cameraFrame == CGSize(width: 3264, height: 2448))
        #expect(estimate.pixelCount == 3264 * 2448)
    }

    @MainActor
    @Test("The estimate follows the quality, the aspect ratio and the format of the camera")
    func followsSettings() async throws {
        let harness = QualityHarness(librarySaving: CaptureTestSupport.makeLibrarySaving(isUserAdjustable: false))
        let settings = harness.settings
        #expect(PhotoSizeEstimate(settings: settings) == nil)
        await harness.camera.start()
        let opening = try #require(PhotoSizeEstimate(settings: settings))
        #expect(opening == estimate())
        settings.select(aspectRatio: .sixteenByNine)
        #expect(PhotoSizeEstimate(settings: settings) == estimate(aspectRatio: .sixteenByNine))
        settings.select(photoFormat: .raw)
        #expect(PhotoSizeEstimate(settings: settings) == estimate(aspectRatio: .sixteenByNine, format: .raw))
        settings.select(photoQuality: .low)
        #expect(PhotoSizeEstimate(settings: settings) == estimate(aspectRatio: .sixteenByNine, quality: .low))
    }

    @MainActor
    @Test("The estimate follows the levels the app set for the medium and the low quality")
    func followsCustomLevels() async throws {
        var levels = CameraFlowQualityLevels()
        levels.medium = CameraFlowQualityLevel(size: .longSide(maximum: 2048), format: .jpeg(quality: 0.8))
        levels.low = CameraFlowQualityLevel(size: .longSide(maximum: 1280), format: .jpeg(quality: 0.6))
        let harness = QualityHarness(levels: levels)
        await harness.camera.start()
        let settings = harness.settings
        settings.select(photoQuality: .medium)
        let medium = try #require(PhotoSizeEstimate(settings: settings))
        #expect(medium.output == CameraFlowQuality.medium.output(within: CameraFlowOutput(), levels: levels))
        expectClose(medium.pixelCount, 2048 * 1536, tolerance: 0.000_001)
        expectClose(medium.bytesPerPixel, 0.23 * 1.3, tolerance: 0.000_001)
        settings.select(photoQuality: .low)
        let low = try #require(PhotoSizeEstimate(settings: settings))
        expectClose(low.pixelCount, 1280 * 960, tolerance: 0.000_001)
        expectClose(low.bytesPerPixel, 0.1525 * 1.3, tolerance: 0.000_001)
        #expect(low.byteCount < medium.byteCount)
        let defaults = QualityHarness()
        await defaults.camera.start()
        defaults.settings.select(photoQuality: .medium)
        let defaultMedium = try #require(PhotoSizeEstimate(settings: defaults.settings))
        expectClose(defaultMedium.pixelCount, 1920 * 1440, tolerance: 0.000_001)
        #expect(defaultMedium.byteCount != medium.byteCount)
    }

    // MARK: - The text

    @Test(
        "The footnote rounds the size to two digits and writes it in the flow's language",
        arguments: [
            (2_072_770, "en-US", "About 2.1 MB per photo."),
            (736_819, "en-US", "About 740 kB per photo."),
            (233_626, "en-US", "About 230 kB per photo."),
            (25_604_813, "en-US", "About 26 MB per photo."),
            (995_000, "en-US", "About 1 MB per photo."),
            (2_072_770, "uk-UA", "Приблизно 2,1 МБ на фото.")
        ]
    )
    func footnote(byteCount: Int, locale: String, expected: String) {
        let localization = FlowLocalization(.specific(Locale.Language(identifier: locale)))
        let text = CameraSettingText(localization).photoSizeFootnote(byteCount: byteCount)
        #expect(text == expected)
    }

    @Test("The quality row has its label, its options and their marks for the top bar")
    func qualityText() {
        #expect(CameraSettingText(.system).qualityTitle == "QUALITY")
        #expect(CameraFlowQuality.allCases.map(CameraSettingText(.system).quality) == ["High", "Medium", "Low"])
        #expect(CameraSettingText(.system).formatMark(format: .raw, quality: .high) == "RAW")
        #expect(CameraSettingText(.system).formatMark(format: .heif, quality: .medium) == "MED")
        #expect(CameraSettingText(.system).formatMark(format: .heif, quality: .low) == "LOW")
    }

    @MainActor
    @Test("The Format indicator reads the quality while it is reduced, and the format otherwise")
    func indicatorValue() async {
        let harness = QualityHarness()
        await harness.camera.start()
        #expect(CameraSettingText(.system).value(of: .format, in: harness.settings) == "HEIF")
        harness.settings.select(photoQuality: .medium)
        #expect(CameraSettingText(.system).value(of: .format, in: harness.settings) == "Medium")
    }
}
