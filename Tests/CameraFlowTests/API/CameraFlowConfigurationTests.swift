//
//  CameraFlowConfigurationTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@testable import CameraFlow

@Suite("Configuration of the flow", .temporaryDirectory, .timeLimit(.minutes(1)))
struct CameraFlowConfigurationTests {

    @Test("The default flow: library, no Live Photo, a switchable circle, no limit, untouched files, no saving")
    func defaults() {
        let configuration = CameraFlowConfiguration()
        #expect(configuration.isLibraryPickerEnabled)
        #expect(configuration.camera.isLivePhotoEnabled == .fixed(false))
        #expect(configuration.camera.isDualCameraEnabled == CameraFlowSetting(false))
        #expect(configuration.photoLimit == .unlimited)
        #expect(configuration.camera == CameraFlowInitialState())
        #expect(configuration.output == CameraFlowOutput())
        #expect(configuration.photoLibrarySaving == CameraFlowPhotoLibrarySaving())
        #expect(configuration.photoLibrarySaving.isEnabled == .fixed(false))
        #expect(configuration.preferences == CameraFlowPreferences())
    }

    @Test("A single photo is a limit of one")
    func single() {
        #expect(CameraFlowPhotoLimit.single == .maximum(1))
    }

    @Test(
        "A limit a set can honour passes the check",
        arguments: [CameraFlowPhotoLimit.unlimited, .single, .maximum(9)]
    )
    func validLimit(limit: CameraFlowPhotoLimit) {
        limit.validate()
    }

    @Test("An output at the smallest size, a separate output of the library and a named album pass the check")
    func validOutputs() {
        var configuration = CameraFlowConfiguration()
        configuration.output.size = .longSide(maximum: 1)
        configuration.output.format = .jpeg(quality: 1)
        configuration.libraryOutput = .separate(CameraFlowOutput())
        configuration.photoLibrarySaving.destination = .album(named: "Field photos")
        configuration.validate()
    }

    /// A configuration at the edge of a rule of the check, which a flow honours.
    enum HonouredConfiguration: String, Sendable, CaseIterable, CustomTestStringConvertible {
        case finiteZoomAndExposure
        case rawWithTheFilesAsTheyAre
        case rawWithAQualityTheUserPicks
        case rawWithAFixedQualityThatKeepsTheFormat
        case albumNameWithSpaces

        var configuration: CameraFlowConfiguration {
            var configuration = CameraFlowConfiguration()
            configuration.settingsMemory = .off
            switch self {
            case .finiteZoomAndExposure:
                configuration.camera.zoomFactor = 0.5
                configuration.camera.exposureBias = .fixed(-8)
            case .rawWithTheFilesAsTheyAre:
                configuration.camera.photoFormat = .fixed(.raw)
            case .rawWithAQualityTheUserPicks:
                configuration.camera.photoFormat = .fixed(.raw)
                configuration.photoQuality = CameraFlowSetting(.low)
            case .rawWithAFixedQualityThatKeepsTheFormat:
                configuration.camera.photoFormat = CameraFlowSetting(.raw)
                configuration.photoQuality = .fixed(.medium)
            case .albumNameWithSpaces:
                configuration.photoLibrarySaving.destination = .album(named: " Field ")
            }
            return configuration
        }

        var testDescription: String {
            rawValue
        }
    }

    @Test("A configuration at the edge of a rule passes the check", arguments: HonouredConfiguration.allCases)
    func honouredConfiguration(honoured: HonouredConfiguration) {
        honoured.configuration.validate()
    }

    #if os(macOS)
    @Test("A limit below one photo stops the program")
    func invalidLimit() async {
        await #expect(processExitsWith: .failure) {
            CameraFlowPhotoLimit.maximum(0).validate()
        }
    }

    /// A configuration the flow refuses: an output it cannot make, a camera state that is not a number, RAW that
    /// the output or a fixed quality cannot keep, or an album without a name.
    enum RefusedConfiguration: String, Sendable, Codable, CaseIterable, CustomTestStringConvertible {
        case noPixels
        case jpegQualityAboveOne
        case heicQualityBelowZero
        case libraryOutputWithoutPixels
        case albumWithoutName
        case albumOfWhiteSpace
        case zoomNotANumber
        case infiniteZoom
        case exposureNotANumber
        case infiniteExposure
        case rawUnderJPEG
        case adjustableRAWUnderStrippedMetadata
        case rawUnderFixedLowQuality

        var configuration: CameraFlowConfiguration {
            var configuration = CameraFlowConfiguration()
            switch self {
            case .noPixels: configuration.output.size = .longSide(maximum: 0)
            case .jpegQualityAboveOne: configuration.output.format = .jpeg(quality: 1.5)
            case .heicQualityBelowZero: configuration.output.format = .heic(quality: -0.1)
            case .libraryOutputWithoutPixels:
                var output = CameraFlowOutput()
                output.size = .longSide(maximum: 0)
                configuration.libraryOutput = .separate(output)
            case .albumWithoutName: configuration.photoLibrarySaving.destination = .album(named: "")
            case .albumOfWhiteSpace: configuration.photoLibrarySaving.destination = .album(named: " \n\t ")
            case .zoomNotANumber: configuration.camera.zoomFactor = .nan
            case .infiniteZoom: configuration.camera.zoomFactor = .infinity
            case .exposureNotANumber: configuration.camera.exposureBias = CameraFlowSetting(.nan)
            case .infiniteExposure: configuration.camera.exposureBias = .fixed(-.infinity)
            case .rawUnderJPEG:
                configuration.camera.photoFormat = .fixed(.raw)
                configuration.output.format = .jpeg(quality: 0.8)
            case .adjustableRAWUnderStrippedMetadata:
                configuration.camera.photoFormat = CameraFlowSetting(.raw)
                configuration.output.metadata = .stripped
            case .rawUnderFixedLowQuality:
                configuration.camera.photoFormat = .fixed(.raw)
                configuration.photoQuality = .fixed(.low)
            }
            return configuration
        }

        var testDescription: String {
            rawValue
        }
    }

    @Test(
        "A configuration no flow can honour stops the program",
        arguments: RefusedConfiguration.allCases
    )
    func refusedConfiguration(refused: RefusedConfiguration) async {
        await #expect(processExitsWith: .failure) { [refused] in
            refused.configuration.validate()
        }
    }
    #endif
}
