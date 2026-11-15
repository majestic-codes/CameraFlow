//
//  QualityTestSupport.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CameraFlow

/// What a flow under test told its app about the quality: the preferences it reported and the sets it handed over.
@MainActor
final class QualityOutcome {
    var preferences: [CameraFlowPreferences] = []
    var handedOver: [[CameraFlowPhoto]] = []
}

/// A camera and a set over one quality, as the flow composes them: the quality opens with the app's stored
/// preference or else with the remembered one, the camera offers it and takes the photos, the set brings in the
/// picks and writes the copies. The second camera's circle is fixed off.
@MainActor
struct QualityHarness {
    let service = RecordingCameraService()
    let haptics = RecordingCameraHaptics()
    let files = CaptureTestSupport.makeFileStore()
    let outcome = QualityOutcome()
    let quality: PhotoQualityModel
    let photoSet: PhotoSetModel
    let camera: PhotoCameraModel

    init(
        setting: CameraFlowSetting<CameraFlowQuality> = CameraFlowSetting(.high),
        preference: CameraFlowQuality? = nil,
        output: CameraFlowOutput = CameraFlowOutput(),
        levels: CameraFlowQualityLevels = CameraFlowQualityLevels(),
        libraryOutput: CameraFlowLibraryOutput = .sameAsCamera,
        initialState: CameraFlowInitialState = CameraFlowInitialState(),
        memory: PreferencesMemory? = nil,
        librarySaving: PhotoLibrarySavingModel? = nil
    ) {
        var state = initialState
        state.isDualCameraEnabled = .fixed(false)
        var preferences = CameraFlowPreferences()
        preferences.photoQuality = preference
        let choices = UserChoices(preferences: preferences, memory: memory) { [outcome] in
            outcome.preferences.append($0)
        }
        let quality = PhotoQualityModel(
            setting: setting,
            preference: choices.reported.photoQuality,
            output: output,
            levels: levels,
            libraryOutput: libraryOutput
        )
        let photoSet = PhotoSetModel(
            limit: .unlimited,
            fileStore: files,
            quality: quality,
            librarySaving: librarySaving,
            renderer: CopyingMarkupRenderer(),
            backgroundWork: RecordingBackgroundWork()
        ) { [outcome] in
            outcome.handedOver.append($0)
        }
        self.quality = quality
        self.photoSet = photoSet
        camera = PhotoCameraModel(
            service: service,
            haptics: haptics,
            attitudeSensor: ManualAttitudeSensor(),
            initialState: state,
            quality: quality,
            choices: choices,
            librarySaving: librarySaving,
            onboarding: OnboardingModel(setting: .off, service: service),
            clock: ManualClock(),
            files: files,
            location: nil,
            heading: nil,
            admission: photoSet,
            storage: FakeStorageSpace(),
            backgroundWork: RecordingBackgroundWork(),
            onCapture: photoSet.add
        )
    }

    var settings: PhotoSettingsModel {
        camera.settings
    }

    /// The harness once its camera has started, which offers the qualities of the camera's photos.
    func started() async -> Self {
        await camera.start()
        return self
    }

    /// Takes a photo with the camera delivering the large photo, and returns it as the set holds it.
    func takeLargePhoto() async throws -> FlowPhoto {
        service.deliveredPhoto = CapturedPhoto(
            imageData: try LargePhotoFixture.heic.get(),
            encoding: .heif,
            livePhotoMovieURL: nil
        )
        await camera.capture()
        return try #require(photoSet.photos.last)
    }

    /// Picks the large photo from the library as a JPEG, and returns it as the set holds it.
    func pickLargePhoto() async throws -> FlowPhoto {
        let pick = FakeLibraryPick(data: try LargePhotoFixture.jpeg.get(), fileExtension: "jpg")
        await photoSet.importPicks([pick])
        return try #require(photoSet.photos.last)
    }
}

/// A renderer that draws nothing: its copy is the photo as the writer of the copies brings it to the output.
struct CopyingMarkupRenderer: MarkupRenderer {

    func image(of drawing: MarkupDrawing, pixelSize: CGSize) throws -> CGImage {
        try FlowTestSupport.makeImage(width: 1, height: 1)
    }

    func writeCopy(
        of photoURL: URL,
        with drawing: MarkupDrawing,
        output: CameraFlowOutput,
        into directory: URL
    ) async throws -> URL {
        try await OverlayPhotoWriter.writeCopy(
            of: photoURL,
            into: directory,
            label: "markup",
            output: output
        ) { _, _ in }
    }
}

/// A photo larger than the reduced qualities allow, 2560 x 1920, with enough detail for the compression to show
/// in the size of its file.
enum LargePhotoFixture {
    enum FixtureError: Error {
        case cannotDraw
        case cannotEncode(String)
    }

    static let width = 2560
    static let height = 1920

    /// The photo as the camera writes it: a HEIC.
    static let heic = Result { try encode(as: .heic) }
    /// The photo as a library has it: a JPEG.
    static let jpeg = Result { try encode(as: .jpeg) }

    /// The file facts a test checks: the type, the pixel size and the byte count.
    struct Facts: Equatable {
        let type: UTType
        let width: Int
        let height: Int
        let byteCount: Int
    }

    static func facts(of url: URL) throws -> Facts {
        let data = try Data(contentsOf: url)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let identifier = try #require(CGImageSourceGetType(source))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return Facts(
            type: try #require(UTType(identifier as String)),
            width: try #require(properties[kCGImagePropertyPixelWidth] as? Int),
            height: try #require(properties[kCGImagePropertyPixelHeight] as? Int),
            byteCount: data.count
        )
    }

    private static func encode(as type: UTType) throws -> Data {
        let image = try makeImage()
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            throw FixtureError.cannotEncode(type.identifier)
        }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.9]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.cannotEncode(type.identifier)
        }
        return data as Data
    }

    /// A slope of grey with noise over it, the same in every run.
    private static func makeImage() throws -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 20_261_111
        for row in 0..<height {
            for column in 0..<width {
                state = state &* 1_664_525 &+ 1_013_904_223
                let noise = Int(state >> 26)
                let slope = (column + row) * 190 / (width + height)
                let offset = (row * width + column) * 4
                pixels[offset] = UInt8(slope + noise)
                pixels[offset + 1] = UInt8(slope + noise / 2)
                pixels[offset + 2] = UInt8(190 - slope + noise)
            }
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            throw FixtureError.cannotDraw
        }
        return image
    }
}
