//
//  CameraFlowLaunchOptions.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
@_spi(Testing) import CameraFlow

/// Launch arguments that open the camera flow in a fixed state, so a screenshot needs no touch input.
///
/// The table of "Running the Example" in the README lists every argument and what it does. Every argument that
/// starts with `-cameraFlow` must be one of them, given once: a misspelled or repeated one, an invalid value, and two
/// arguments that ask for opposite things stop the launch with the error on screen. Other arguments, such as
/// `-AppleLanguages`, are left to the system.
///
/// The example opens with saving to the photo library on and switchable, so the introduction asks for the library,
/// and with the quality row, high at first. `-cameraFlowLock` takes the controls of the named settings away, so the
/// values of the arguments hold, and a level that `-cameraFlowQualityLevels` leaves out keeps the package's default.
/// The stored preferences and the flow's own memory combine as in an app: with both `-cameraFlowNoMemory` and
/// `-cameraFlowNoPreferences` the flow opens with the values of the arguments, with `-cameraFlowNoMemory` alone the
/// example's stored preferences are the only memory, and with neither the stored preferences go before what the flow
/// remembers.
struct CameraFlowLaunchOptions {
    var opensAtLaunch = false
    var opensThroughUIKit = false
    var appliesStoredPreferences = true
    /// Whether the launch removes what the example and the flow stored in the defaults before anything reads it.
    var resetsState = false
    var configuration = Self.exampleConfiguration

    /// The package's default flow with the switch for saving to the photo library, on at first, and the choice of
    /// the quality shown, so the example offers both.
    private static var exampleConfiguration: CameraFlowConfiguration {
        var configuration = CameraFlowConfiguration()
        configuration.photoLibrarySaving.destination = .library
        configuration.photoLibrarySaving.isEnabled = CameraFlowSetting(true)
        configuration.photoQuality = CameraFlowSetting(.high)
        return configuration
    }

    enum ParseError: Error {
        case missingValue(String)
        case invalidValue(argument: String, value: String)
        /// The sub-panel of a setting the flow of these arguments does not have.
        case unavailableSubPanel(String)
        /// An argument of the example that does not exist, such as a misspelled one.
        case unknownArgument(String)
        /// An argument of the example given more than once.
        case repeatedArgument(String)
        /// Arguments of which a launch takes one at most.
        case conflictingArguments([String])
    }

    /// The beginning of every argument of the example.
    private static let prefix = "-cameraFlow"

    private static let valuedArguments: Set = [
        "-cameraFlowLimit", "-cameraFlowScene", "-cameraFlowAutoCapture", "-cameraFlowSubPanel", "-cameraFlowSize",
        "-cameraFlowFormat", "-cameraFlowSaveToAlbum", "-cameraFlowLock", "-cameraFlowAspect", "-cameraFlowTimer",
        "-cameraFlowExposure", "-cameraFlowRotation", "-cameraFlowQuality", "-cameraFlowQualityLevels",
        "-cameraFlowAccess", "-cameraFlowStartFailures", "-cameraFlowLanguage", "-cameraFlowSaveMoment"
    ]

    /// Groups of arguments that ask for opposite things: the two ways to open the flow, and the saving to the photo
    /// library off or on at a destination.
    private static let exclusiveArguments = [
        ["-cameraFlow", "-cameraFlowUIKit"],
        ["-cameraFlowNoLibrarySave", "-cameraFlowSaveToLibrary", "-cameraFlowSaveToAlbum"]
    ]

    init(arguments: [String]) throws {
        var given: Set<String> = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1
            guard argument.hasPrefix(Self.prefix) else { continue }
            guard given.insert(argument).inserted else { throw ParseError.repeatedArgument(argument) }
            if Self.valuedArguments.contains(argument) {
                guard index < arguments.count else { throw ParseError.missingValue(argument) }
                try apply(argument, value: arguments[index])
                index += 1
            } else {
                try apply(argument)
            }
        }
        for group in Self.exclusiveArguments {
            let conflicting = group.filter(given.contains)
            guard conflicting.count < 2 else { throw ParseError.conflictingArguments(conflicting) }
        }
        if case let .subPanel(setting) = configuration.camera.panel, !offersSubPanel(of: setting) {
            throw ParseError.unavailableSubPanel(setting.rawValue)
        }
    }

    private mutating func apply(_ flag: String) throws {
        switch flag {
        case "-cameraFlow": opensAtLaunch = true
        case "-cameraFlowUIKit": opensThroughUIKit = true
        case "-cameraFlowResetState": resetsState = true
        case "-cameraFlowNoLibrary": configuration.isLibraryPickerEnabled = false
        case "-cameraFlowLive": configuration.camera.isLivePhotoEnabled.isUserAdjustable = true
        case "-cameraFlowNoLocation": configuration.photoLocation = .off
        case "-cameraFlowNoPreferences": appliesStoredPreferences = false
        case "-cameraFlowSimulated": configuration.camera.usesSimulatedCamera = true
        case "-cameraFlowPanel": configuration.camera.panel = .tiles
        case "-cameraFlowDial": configuration.camera.isZoomDialOpen = true
        case "-cameraFlowStripMetadata": configuration.output.metadata = .stripped
        case "-cameraFlowRAW": configuration.camera.photoFormat.value = .raw
        case "-cameraFlowSaveToLibrary": configuration.photoLibrarySaving.isEnabled.value = true
        case "-cameraFlowNoLibrarySave": configuration.photoLibrarySaving.isEnabled.value = false
        case "-cameraFlowDualCamera": configuration.camera.isDualCameraEnabled.value = true
        case "-cameraFlowDualCameraSwapped":
            configuration.camera.isDualCameraEnabled.value = true
            configuration.camera.isDualCameraSwapped = true
        case "-cameraFlowNoMemory": configuration.settingsMemory = .off
        case "-cameraFlowNoOnboarding": configuration.onboarding = .off
        case "-cameraFlowSinglePhoto": configuration.completion = .afterOnePhoto
        case "-cameraFlowDirection": configuration.photoDirection = .recorded
        case "-cameraFlowLibraryOriginal": configuration.libraryOutput = .separate(CameraFlowOutput())
        default: throw ParseError.unknownArgument(flag)
        }
    }

    private mutating func apply(_ argument: String, value: String) throws {
        let invalid = ParseError.invalidValue(argument: argument, value: value)
        switch argument {
        case "-cameraFlowLimit":
            guard let count = Int(value), count >= 1 else { throw invalid }
            configuration.photoLimit = .maximum(count)
        case "-cameraFlowScene":
            let channels = value.split(separator: ",").compactMap { Double($0) }
            guard channels.count == 3, channels.allSatisfy((0...255).contains) else { throw invalid }
            let color = channels.map { $0 / 255 }
            configuration.camera.simulatedScene = .color(red: color[0], green: color[1], blue: color[2])
        case "-cameraFlowAutoCapture":
            guard let count = Int(value), count > 0 else { throw invalid }
            configuration.camera.automaticCaptureCount = count
        case "-cameraFlowSubPanel":
            guard let setting = CameraSetting(rawValue: value) else { throw invalid }
            configuration.camera.panel = .subPanel(setting)
        case "-cameraFlowSize":
            if value == "standard" {
                configuration.output.size = .standard
            } else {
                guard let maximum = Int(value), maximum >= 1 else { throw invalid }
                configuration.output.size = .longSide(maximum: maximum)
            }
        case "-cameraFlowFormat":
            configuration.output.format = try Self.format(value, invalid: invalid)
        case "-cameraFlowQuality":
            guard let quality = CameraFlowQuality(rawValue: value) else { throw invalid }
            configuration.photoQuality.value = quality
        case "-cameraFlowQualityLevels":
            try applyQualityLevels(value, invalid: invalid)
        case "-cameraFlowSaveToAlbum":
            guard !value.isEmpty else { throw invalid }
            configuration.photoLibrarySaving.destination = .album(named: value)
            configuration.photoLibrarySaving.isEnabled.value = true
        case "-cameraFlowLock":
            try lock(value.split(separator: ",").map(String.init), invalid: invalid)
        case "-cameraFlowLanguage":
            guard !value.isEmpty else { throw invalid }
            configuration.language = .specific(Locale.Language(identifier: value))
        case "-cameraFlowSaveMoment":
            let moments: [String: CameraFlowPhotoLibrarySaving.Moment] = [
                "whenSetAccepted": .whenSetAccepted, "afterEachPhoto": .afterEachPhoto
            ]
            guard let moment = moments[value] else { throw invalid }
            configuration.photoLibrarySaving.moment = moment
        default:
            try applyCameraValue(argument, value: value, invalid: invalid)
        }
    }

    /// The valued arguments that set a camera setting or the simulated device.
    private mutating func applyCameraValue(_ argument: String, value: String, invalid: ParseError) throws {
        switch argument {
        case "-cameraFlowAspect":
            guard let aspectRatio = CameraFlowAspectRatio(rawValue: value) else { throw invalid }
            configuration.camera.aspectRatio.value = aspectRatio
        case "-cameraFlowTimer":
            guard let seconds = Int(value), let timer = CameraFlowTimer(rawValue: seconds) else { throw invalid }
            configuration.camera.timer.value = timer
        case "-cameraFlowExposure":
            guard let bias = Double(value), bias.isFinite else { throw invalid }
            configuration.camera.exposureBias.value = bias
        case "-cameraFlowRotation":
            let orientations: [String: CameraOrientation] = [
                "portrait": .portrait, "left": .landscapeLeft, "right": .landscapeRight, "down": .upsideDown
            ]
            guard let orientation = orientations[value] else { throw invalid }
            configuration.camera.simulatedOrientation = orientation
        case "-cameraFlowAccess":
            try applyAccess(value, invalid: invalid)
        case "-cameraFlowStartFailures":
            guard let count = Int(value), count >= 0 else { throw invalid }
            configuration.camera.usesSimulatedCamera = true
            configuration.camera.simulatedStartFailureCount = count
        default:
            throw invalid
        }
    }

    /// `camera`, `library`, `denied`, `location`, `locationDenied`, `all`, `locationAndLibrary` and `libraryAlone`
    /// open the simulated camera with access the user was not asked for yet, or refused when asked.
    private mutating func applyAccess(_ value: String, invalid: ParseError) throws {
        let accesses: [String: SimulatedAccess] = [
            "camera": .cameraNotAsked, "library": .cameraAndPhotoLibraryNotAsked, "denied": .cameraDenied,
            "location": .locationNotAsked, "locationDenied": .locationDenied,
            "all": .cameraLocationAndPhotoLibraryNotAsked, "locationAndLibrary": .locationAndPhotoLibraryNotAsked,
            "libraryAlone": .photoLibraryNotAsked
        ]
        guard let access = accesses[value] else { throw invalid }
        configuration.camera.usesSimulatedCamera = true
        configuration.simulatedAccess = access
    }

    /// `jpeg:0.8` or `heic:0.7`.
    private static func format(_ value: String, invalid: ParseError) throws -> CameraFlowOutputFormat {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let quality = Double(parts[1]), (0...1).contains(quality) else { throw invalid }
        switch parts[0] {
        case "jpeg": return .jpeg(quality: quality)
        case "heic": return .heic(quality: quality)
        default: throw invalid
        }
    }

    /// `medium=2048:jpeg:0.8,low=1280:jpeg:0.6`: the long side of a level and its format, or the long side alone
    /// for the format of the output.
    private mutating func applyQualityLevels(_ value: String, invalid: ParseError) throws {
        let entries = value.split(separator: ",")
        guard !entries.isEmpty else { throw invalid }
        for entry in entries {
            let sides = entry.split(separator: "=", maxSplits: 1)
            guard sides.count == 2 else { throw invalid }
            let parts = sides[1].split(separator: ":", maxSplits: 1)
            guard let first = parts.first, let longSide = Int(first), longSide >= 1 else { throw invalid }
            var level = CameraFlowQualityLevel(size: .longSide(maximum: longSide))
            if parts.count == 2 {
                level.format = try Self.format(String(parts[1]), invalid: invalid)
            }
            switch sides[0] {
            case "medium": configuration.photoQualityLevels.medium = level
            case "low": configuration.photoQualityLevels.low = level
            default: throw invalid
            }
        }
    }

    /// Fixes the named settings to the values they have.
    private mutating func lock(_ names: [String], invalid: ParseError) throws {
        for name in names {
            switch name {
            case "flash": configuration.camera.flashMode.isUserAdjustable = false
            case "live": configuration.camera.isLivePhotoEnabled.isUserAdjustable = false
            case "aspect": configuration.camera.aspectRatio.isUserAdjustable = false
            case "timer": configuration.camera.timer.isUserAdjustable = false
            case "exposure": configuration.camera.exposureBias.isUserAdjustable = false
            case "format": configuration.camera.photoFormat.isUserAdjustable = false
            case "dual": configuration.camera.isDualCameraEnabled.isUserAdjustable = false
            case "save": configuration.photoLibrarySaving.isEnabled.isUserAdjustable = false
            case "quality": configuration.photoQuality.isUserAdjustable = false
            default: throw invalid
            }
        }
    }

    /// Whether the Format panel has the quality row: the user may pick, and the output leaves something to pick.
    private var offersQuality: Bool {
        let qualities = CameraFlowQuality.distinct(
            within: configuration.output,
            levels: configuration.photoQualityLevels
        )
        return configuration.photoQuality.isUserAdjustable && qualities.count > 1
    }

    /// Whether the flow of these arguments has a tile for the setting.
    private func offersSubPanel(of setting: CameraSetting) -> Bool {
        let camera = configuration.camera
        return switch setting {
        case .flash: camera.flashMode.isUserAdjustable
        case .live: camera.isLivePhotoEnabled.isUserAdjustable
        case .aspect: camera.aspectRatio.isUserAdjustable
        case .timer: camera.timer.isUserAdjustable
        case .exposure: camera.exposureBias.isUserAdjustable
        case .format: camera.photoFormat.isUserAdjustable || offersQuality
        case .dualCamera: camera.isDualCameraEnabled.isUserAdjustable
        case .librarySave: configuration.photoLibrarySaving.isEnabled.isUserAdjustable
        }
    }
}
