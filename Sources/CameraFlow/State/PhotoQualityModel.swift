//
//  PhotoQualityModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The quality of the photos the app receives and the output it makes of the app's own, shared by the camera, which
/// offers the choice and takes the photos, and the set, which brings in the picks from the photo library.
///
/// The flow opens with the stored preference where the user may choose, and with the app's value otherwise. A
/// quality whose output is the same as a better one's is taken as that better one, so the quality in effect is
/// always one the panel can show. What the medium and the low quality give are the levels of the app.
@MainActor
@Observable
final class PhotoQualityModel {
    private(set) var quality: CameraFlowQuality
    /// The qualities the user picks among, best first. Empty when the app fixed the quality or its output leaves
    /// nothing to choose.
    let offered: [CameraFlowQuality]

    /// The output of the app, which no quality exceeds.
    @ObservationIgnored private let appOutput: CameraFlowOutput
    /// What the medium and the low quality mean in this flow.
    @ObservationIgnored private let levels: CameraFlowQualityLevels
    /// The output of the picks from the photo library.
    @ObservationIgnored private let libraryOutput: CameraFlowLibraryOutput

    init(
        setting: CameraFlowSetting<CameraFlowQuality>,
        preference: CameraFlowQuality?,
        output: CameraFlowOutput,
        levels: CameraFlowQualityLevels,
        libraryOutput: CameraFlowLibraryOutput
    ) {
        appOutput = output
        self.levels = levels
        self.libraryOutput = libraryOutput
        let distinct = CameraFlowQuality.distinct(within: output, levels: levels)
        let isChoice = setting.isUserAdjustable && distinct.count > 1
        offered = isChoice ? distinct : []
        let opening = isChoice ? setting.resolved(with: preference) : setting.value
        quality = opening.offered(within: output, levels: levels)
    }

    /// Whether the user picks the quality: the Format panel then has its row.
    var isUserAdjustable: Bool {
        !offered.isEmpty
    }

    /// The output of the next photo: the app's, narrowed by the quality.
    var output: CameraFlowOutput {
        quality.output(within: appOutput, levels: levels)
    }

    /// The output of the next pick from the photo library: the camera's, or the one the app gave the picks.
    var photoLibraryOutput: CameraFlowOutput {
        switch libraryOutput {
        case .sameAsCamera: output
        case let .separate(output): output
        }
    }

    /// The widest output a quality the user may pick gives, which is the app's own where there is a choice.
    var widestOutput: CameraFlowOutput {
        (offered.first ?? quality).output(within: appOutput, levels: levels)
    }

    /// Whether the user moved the quality off the best one.
    var isReduced: Bool {
        isUserAdjustable && quality != offered.first
    }

    /// Takes a quality of the row and returns whether that changed anything.
    func select(_ quality: CameraFlowQuality) -> Bool {
        guard offered.contains(quality), self.quality != quality else { return false }
        self.quality = quality
        return true
    }
}
