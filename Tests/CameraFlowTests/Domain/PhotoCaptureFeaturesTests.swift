//
//  PhotoCaptureFeaturesTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The costly photo features a flow turns on in its camera", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoCaptureFeaturesTests {
    // MARK: - What a flow can use

    @Test(
        "Live Photo is on only in a flow that offers it or fixes it on",
        arguments: [
            (CameraFlowSetting.fixed(false), false),
            (.fixed(true), true),
            (CameraFlowSetting(false), true),
            (CameraFlowSetting(true), true)
        ]
    )
    func livePhoto(setting: CameraFlowSetting<Bool>, isOn: Bool) {
        var camera = CameraFlowInitialState()
        camera.isLivePhotoEnabled = setting
        let features = PhotoCaptureFeatures(camera: camera, output: CameraFlowOutput())
        #expect(features.livePhoto == isOn)
    }

    @Test("The default flow has no Live Photo, so its camera does not turn it on")
    func defaultFlow() {
        let features = PhotoCaptureFeatures(camera: CameraFlowInitialState(), output: CameraFlowOutput())
        #expect(features == PhotoCaptureFeatures(livePhoto: false, raw: true))
    }

    @Test(
        "RAW is on only in a flow that offers the format or fixes it to RAW",
        arguments: [
            (CameraFlowSetting.fixed(CameraFlowPhotoFormat.heif), false),
            (.fixed(.raw), true),
            (CameraFlowSetting(.heif), true),
            (CameraFlowSetting(.raw), true)
        ]
    )
    func raw(setting: CameraFlowSetting<CameraFlowPhotoFormat>, isOn: Bool) {
        var camera = CameraFlowInitialState()
        camera.photoFormat = setting
        let features = PhotoCaptureFeatures(camera: camera, output: CameraFlowOutput())
        #expect(features.raw == isOn)
    }

    @Test("RAW is off under an output that re-encodes the file or strips its metadata, whatever the format says")
    func rawUnderOutput() {
        var camera = CameraFlowInitialState()
        camera.photoFormat = .fixed(.raw)
        var reencoded = CameraFlowOutput()
        reencoded.format = .jpeg(quality: 0.8)
        var stripped = CameraFlowOutput()
        stripped.metadata = .stripped
        var scaled = CameraFlowOutput()
        scaled.size = .standard
        #expect(PhotoCaptureFeatures(camera: camera, output: reencoded).raw == false)
        #expect(PhotoCaptureFeatures(camera: camera, output: stripped).raw == false)
        #expect(PhotoCaptureFeatures(camera: camera, output: scaled).raw)
    }

    // MARK: - What the camera then has

    @Test("A camera narrowed to the features of a flow reports only those, and keeps everything else")
    func narrowedCapabilities() {
        let whole = SimulatedCameraService.iPhoneBackPhotoCapabilities
        #expect(whole.narrowed(to: .all) == whole)
        let narrowed = whole.narrowed(to: PhotoCaptureFeatures(livePhoto: false, raw: false))
        #expect(narrowed.isLivePhotoSupported == false)
        #expect(narrowed.formats == [.heif])
        #expect(narrowed.flashModes == whole.flashModes)
        #expect(narrowed.resolution == whole.resolution)
        #expect(narrowed.exposureBiasRange == whole.exposureBiasRange)
        let liveOnly = whole.narrowed(to: PhotoCaptureFeatures(livePhoto: true, raw: false))
        #expect(liveOnly.isLivePhotoSupported)
        #expect(liveOnly.formats == [.heif])
    }

    @Test("A feature the camera lacks stays off when the flow can use it")
    func unsupportedFeature() {
        let narrow = CaptureTestSupport.narrowCapabilities.narrowed(to: .all)
        #expect(narrow.isLivePhotoSupported == false)
        #expect(narrow.formats == [.heif])
    }
}
