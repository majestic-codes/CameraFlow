//
//  PhotoSizeTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Testing
@_spi(Testing) @testable import CameraFlow

@MainActor
@Suite("The size the camera shoots at", .temporaryDirectory, .timeLimit(.minutes(1)))
struct PhotoSizeTests {
    /// A device and a configuration, with the megapixels they shoot at.
    struct SizeCase: Sendable, CustomTestStringConvertible {
        let name: String
        var capabilities = SimulatedCameraService.iPhoneBackPhotoCapabilities
        var isSavingOn = false
        var size = CameraFlowOutputSize.original
        var isDualCameraOn = false
        var isFrontCamera = false
        var fitsOutput = true
        var megapixels = 12

        var testDescription: String {
            name
        }
    }

    nonisolated static let sizeCases = [
        SizeCase(name: "the back camera"),
        SizeCase(name: "saving on", isSavingOn: true),
        SizeCase(name: "a size limit of 12 MP", size: .longSide(maximum: 4032)),
        SizeCase(name: "a size limit below 12 MP", size: .standard, fitsOutput: false),
        SizeCase(name: "the front camera", isFrontCamera: true),
        SizeCase(name: "the dual camera on", isDualCameraOn: true),
        SizeCase(name: "a camera with 8 MP only", capabilities: CaptureTestSupport.dualWithSmallerSize, megapixels: 8)
    ]

    private func makeModel(sizeCase: SizeCase) -> PhotoCameraModel {
        var state = CameraFlowInitialState()
        state.isDualCameraEnabled = .fixed(sizeCase.isDualCameraOn)
        var output = CameraFlowOutput()
        output.size = sizeCase.size
        let model = makeCaptureModel(
            service: RecordingCameraService(backPhotoCapabilities: sizeCase.capabilities),
            initialState: state,
            isDualCameraOffered: sizeCase.isDualCameraOn,
            output: output,
            librarySaving: CaptureTestSupport.makeLibrarySaving(isOn: sizeCase.isSavingOn)
        )
        model.dualCamera.circleLaidOut(DualCameraFixture.circleOnScreen)
        return model
    }

    @Test("A camera shoots at 12 MP where it has them and at its own size otherwise", arguments: sizeCases)
    func sizeInEffect(sizeCase: SizeCase) async {
        let model = makeModel(sizeCase: sizeCase)
        await model.start()
        if sizeCase.isFrontCamera {
            await model.flipCamera()
        }
        #expect(model.dualCamera.isOn == sizeCase.isDualCameraOn)
        let settings = model.settings
        #expect(settings.effectivePhotoFrame?.megapixels == sizeCase.megapixels)
        #expect(settings.effectivePhotoFrame?.isPreferred == (sizeCase.megapixels == 12))
        #expect(settings.deliversPhotos(within: settings.output) == sizeCase.fitsOutput)
    }

    @Test("Before the camera has started there is no size, and nothing fits an output")
    func beforeStart() {
        let model = makeModel(sizeCase: SizeCase(name: "the back camera"))
        #expect(model.settings.effectivePhotoFrame == nil)
        #expect(model.settings.deliversPhotos(within: model.settings.output) == false)
    }

    @Test("A camera that reports no photo size takes no photo and says why")
    func noSize() async {
        let capabilities = PhotoCaptureCapabilities(
            flashModes: CameraFlowFlashMode.allCases,
            isLivePhotoSupported: false,
            exposureBiasRange: -8...8,
            formats: [.heif],
            encodesHEVC: true,
            resolution: nil,
            lockableAdjustments: .focusAndExposure
        )
        let service = RecordingCameraService(backPhotoCapabilities: capabilities)
        let model = makeCaptureModel(service: service)
        await model.start()
        await model.capture()
        #expect(model.notices.captureError == .unsupported(.resolution))
        #expect(service.captureRequests.isEmpty)
    }

    @Test("The size does not change with the zoom")
    func zoomLeavesTheSize() async {
        let model = makeModel(sizeCase: SizeCase(name: "the back camera"))
        await model.start()
        model.zoom.setZoom(2)
        #expect(model.settings.effectivePhotoFrame?.isPreferred == true)
    }
}
