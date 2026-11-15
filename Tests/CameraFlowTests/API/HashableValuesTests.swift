//
//  HashableValuesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) import CameraFlow

/// The public values in sets, as dictionary keys and as the tags of a picker: equal values are one value and hash
/// alike, and values that differ in anything are two.
@Suite("The public values are hashable")
struct HashableValuesTests {
    /// One change to the default configuration, in one of its properties.
    enum Change: String, Sendable, CaseIterable, CustomTestStringConvertible {
        case libraryPicker
        case photoLimit
        case completion
        case zoom
        case flashMode
        case flashAdjustability
        case exposureBias
        case panel
        case simulatedScene
        case outputSize
        case outputFormat
        case libraryOutput
        case photoQuality
        case qualityLevels
        case album
        case moment
        case preferences
        case settingsMemory
        case onboarding
        case photoLocation
        case language
        case photoDirection
        case simulatedAccess

        var configuration: CameraFlowConfiguration {
            var configuration = CameraFlowConfiguration()
            switch self {
            case .libraryPicker: configuration.isLibraryPickerEnabled = false
            case .photoLimit: configuration.photoLimit = .maximum(3)
            case .completion: configuration.completion = .afterOnePhoto
            case .zoom: configuration.camera.zoomFactor = 2
            case .flashMode: configuration.camera.flashMode = CameraFlowSetting(.off)
            case .flashAdjustability: configuration.camera.flashMode.isUserAdjustable = false
            case .exposureBias: configuration.camera.exposureBias = CameraFlowSetting(0.7)
            case .panel: configuration.camera.panel = .subPanel(.timer)
            case .simulatedScene: configuration.camera.simulatedScene = .color(red: 0.1, green: 0.4, blue: 0.8)
            case .outputSize: configuration.output.size = .standard
            case .outputFormat: configuration.output.format = .jpeg(quality: 0.8)
            case .libraryOutput: configuration.libraryOutput = .separate(CameraFlowOutput())
            case .photoQuality: configuration.photoQuality = CameraFlowSetting(.low)
            case .qualityLevels: configuration.photoQualityLevels.low = CameraFlowQualityLevel(size: .original)
            case .album: configuration.photoLibrarySaving.destination = .album(named: "Field photos")
            case .moment: configuration.photoLibrarySaving.moment = .afterEachPhoto
            case .preferences: configuration.preferences.timer = .tenSeconds
            case .settingsMemory: configuration.settingsMemory = .userDefaults(suiteName: "group.example.shared")
            case .onboarding: configuration.onboarding = .off
            case .photoLocation: configuration.photoLocation = .off
            case .language: configuration.language = .specific(Locale.Language(identifier: "uk"))
            case .photoDirection: configuration.photoDirection = .recorded
            case .simulatedAccess: configuration.simulatedAccess = .cameraDenied
            }
            return configuration
        }

        var testDescription: String {
            rawValue
        }
    }

    @Test(
        "A configuration with one change is another one, and equal configurations hash alike",
        arguments: Change.allCases
    )
    func configuration(change: Change) {
        let changed = change.configuration
        let again = change.configuration
        #expect(changed != CameraFlowConfiguration())
        #expect(changed == again)
        #expect(changed.hashValue == again.hashValue)
        #expect(Set([changed, again, CameraFlowConfiguration()]).count == 2)
    }

    @Test("Photos handed over are one photo when equal, and two when anything of them differs")
    func photos() throws {
        let thumbnail = try FlowTestSupport.makeImage(width: 1, height: 1)
        let identifier = UUID()
        let original = CameraFlowPhoto.File(url: URL(filePath: "/photos/photo.heic"), contentType: .heic)
        let makePhoto = { (save: CameraFlowPhotoLibrarySave?) in
            CameraFlowPhoto(
                id: identifier,
                source: .camera,
                original: original,
                thumbnail: thumbnail,
                photoLibrarySave: save
            )
        }
        let photo = makePhoto(nil)
        let same = makePhoto(nil)
        let saved = makePhoto(.saved(CameraFlowPhotoLibraryAsset(localIdentifier: "asset-1")))
        #expect(photo == same)
        #expect(photo.hashValue == same.hashValue)
        #expect(photo != saved)
        #expect(Set([photo, same, saved]).count == 2)
    }

    @Test("Values with a payload tell their payloads apart, as the tags of a picker do")
    func payloads() {
        #expect(Set<CameraFlowPhotoLimit>([.unlimited, .single, .maximum(1), .maximum(5)]).count == 3)
        let sizes: [CameraFlowOutputSize] = [.original, .standard, .longSide(maximum: 1920), .longSide(maximum: 800)]
        #expect(Set(sizes).count == 3)
        let jpeg = CameraFlowOutputFormat.jpeg(quality: 0.8)
        let formats: [CameraFlowOutputFormat] = [.original, jpeg, jpeg, .heic(quality: 0.8)]
        #expect(Set(formats).count == 3)
        let ukrainian = CameraFlowLanguage.specific(Locale.Language(identifier: "uk"))
        #expect(Set([CameraFlowLanguage.system, ukrainian, ukrainian]).count == 2)
        let album = CameraFlowPhotoLibrarySaving.Destination.album(named: "A")
        #expect(Set([CameraFlowPhotoLibrarySaving.Destination.library, album, album, .album(named: "B")]).count == 3)
        #expect(Set([CameraFlowSetting(true), .fixed(true), CameraFlowSetting(true)]).count == 2)
        let denied = CameraFlowPhotoLibrarySaveFailure.accessDenied
        #expect(Set([denied, .libraryError(.notEnoughSpace), denied]).count == 2)
    }
}
