//
//  ConfigurationDefaults.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
@_spi(Testing) @testable import CameraFlow

// The package passes these values at every call, from the app's configuration. Here a test may leave them out, and
// gets the defaults of the configuration.

extension PhotoQualityModel {
    /// A quality model whose picks from the photo library share the camera's output: a fixed high quality over the
    /// default output and levels, unless the test says otherwise.
    convenience init(
        setting: CameraFlowSetting<CameraFlowQuality> = .fixed(.high),
        preference: CameraFlowQuality? = nil,
        output: CameraFlowOutput = CameraFlowOutput(),
        levels: CameraFlowQualityLevels = CameraFlowQualityLevels()
    ) {
        self.init(
            setting: setting,
            preference: preference,
            output: output,
            levels: levels,
            libraryOutput: .sameAsCamera
        )
    }
}

extension CameraFlowQuality {

    /// The output of this quality inside an output, with the default levels.
    func output(within output: CameraFlowOutput) -> CameraFlowOutput {
        self.output(within: output, levels: CameraFlowQualityLevels())
    }

    /// The qualities that differ inside an output with the default levels, best first.
    static func distinct(within output: CameraFlowOutput) -> [Self] {
        distinct(within: output, levels: CameraFlowQualityLevels())
    }

    /// The best quality that gives the same output as this one inside an output with the default levels.
    func offered(within output: CameraFlowOutput) -> Self {
        offered(within: output, levels: CameraFlowQualityLevels())
    }
}

extension OnboardingModel {
    /// The introduction of a flow that never saves to the photo library. It asks for the location through
    /// `location` where it is given.
    convenience init(
        setting: CameraFlowOnboarding,
        service: any CameraService,
        location: (any LocationAuthorizer)? = nil
    ) {
        self.init(setting: setting, service: service, location: location, librarySaving: nil)
    }

    /// The introduction of a flow that never asks for the location.
    convenience init(
        setting: CameraFlowOnboarding,
        service: any CameraService,
        librarySaving: PhotoLibrarySavingModel?
    ) {
        self.init(setting: setting, service: service, location: nil, librarySaving: librarySaving)
    }
}

extension CameraScreenLayout {
    /// The layout of an interface that stands in portrait: with a 4:3 viewfinder and the panel hidden, unless the
    /// test says otherwise.
    init(
        size: CGSize,
        safeAreaTop: CGFloat,
        aspectRatio: CameraFlowAspectRatio = .fourByThree,
        panel: CameraPanelPresentation = .hidden,
        panelTileCount: Int
    ) {
        self.init(
            size: size,
            safeAreaTop: safeAreaTop,
            aspectRatio: aspectRatio,
            panel: panel,
            panelTileCount: panelTileCount,
            interfaceOrientation: .portrait
        )
    }
}

extension OverlayPhotoWriter {

    /// Writes the copy with the overlay at the default output: at the photo's size, with its metadata, in its type.
    @concurrent
    static func writeCopy(
        of photoURL: URL,
        into directory: URL,
        label: String,
        maximumPixelCount: Int = maximumPixelCount,
        drawOverlay: OverlayDrawing
    ) async throws -> URL {
        try await writeCopy(
            of: photoURL,
            into: directory,
            label: label,
            output: CameraFlowOutput(),
            maximumPixelCount: maximumPixelCount,
            drawOverlay: drawOverlay
        )
    }
}
