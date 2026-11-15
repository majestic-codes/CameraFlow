//
//  SimulatedCameraService.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import CoreGraphics
import Foundation
import ImageIO
import os

/// A camera with no hardware behind it: an iPhone 17 Pro lens set over a flat preview.
///
/// Photos of the back camera are a flat 4:3 frame of the scene colour in a file shaped like the device's
/// (`SimulatedPhotoFile`), encoded off the main actor. HEIF is HEVC where ImageIO can encode it and JPEG otherwise; a
/// "RAW" photo is that same processed file marked `.appleProRAW`, since ImageIO cannot write a DNG. Like the device,
/// the file carries no GPS: the request's location comes next to it. The Live Photo movie is an empty stand-in, which
/// the system photo library refuses.
///
/// Like the device's, a capture ends with its session: one in flight when the camera stops or starts again throws
/// `CameraServiceError.notRunning`, and a stopped camera takes no photo.
///
/// The front camera alone shows a `SimulatedDualPicture` of the scene colour, and its dual camera one for each camera,
/// the scene colour for the back one and an orange for the front one. The front camera is mirrored on screen and
/// never in a photo. With the back camera in the viewfinder the pair offers what `dualPhotoCapabilities` says, with
/// the front one what the front camera offers alone.
@MainActor
final class SimulatedCameraService: CameraService {
    private let scene: SimulatedScene
    private let backPhotoCapabilities: PhotoCaptureCapabilities
    private let frontPhotoCapabilities: PhotoCaptureCapabilities
    private let dualPhotoCapabilities: PhotoCaptureCapabilities
    let isDualCameraSupported: Bool
    private(set) var isAuthorizationDetermined: Bool
    /// The answer the camera gives when it is asked for.
    private let authorizationOnRequest: CameraAuthorization
    private(set) var photoCapabilities: PhotoCaptureCapabilities?
    /// The camera that runs alone, the back one before any has started.
    private var singlePosition = CameraPosition.back
    /// The camera in the viewfinder of the dual camera, nil while one camera runs alone.
    private var dualMainPosition: CameraPosition?
    /// How many starts still fail before the camera starts.
    private var remainingStartFailures: Int
    private var mainPreviews: [WeakPreview] = []
    private var circlePreviews: [WeakPreview] = []
    /// Where the camera writes its Live Photo movies before they are moved beside their photos.
    var temporaryDirectory = FileManager.default.temporaryDirectory
    private var isRunning = false
    /// Goes up whenever the camera starts or stops, which ends the captures in flight.
    private var sessionNumber = 0

    private struct WeakPreview {
        weak var preview: SimulatedPreview?
    }

    /// The virtual back camera of the iPhone 17 Pro as the flow's camera reports it.
    nonisolated static let iPhoneBackPhotoCapabilities = PhotoCaptureCapabilities(
        flashModes: CameraFlowFlashMode.allCases,
        isLivePhotoSupported: true,
        exposureBiasRange: -8...8,
        formats: CameraFlowPhotoFormat.allCases,
        encodesHEVC: true,
        resolution: PhotoCaptureResolution(width: 4032, height: 3024),
        lockableAdjustments: .focusAndExposure
    )

    /// The front camera of the iPhone 17 Pro as the flow's camera reports it: its photo output offers the flash of the
    /// screen.
    nonisolated static let iPhoneFrontPhotoCapabilities = PhotoCaptureCapabilities(
        flashModes: CameraFlowFlashMode.allCases,
        isLivePhotoSupported: true,
        exposureBiasRange: -8...8,
        formats: [.heif],
        encodesHEVC: true,
        resolution: PhotoCaptureResolution(width: 4032, height: 3024),
        lockableAdjustments: .focusAndExposure
    )

    /// The back camera of the pair: a dual camera format offers no Live Photo, no RAW and 12 MP only.
    nonisolated static let iPhoneDualPhotoCapabilities = PhotoCaptureCapabilities(
        flashModes: CameraFlowFlashMode.allCases,
        isLivePhotoSupported: false,
        exposureBiasRange: -8...8,
        formats: [.heif],
        encodesHEVC: true,
        resolution: PhotoCaptureResolution(width: 4032, height: 3024),
        lockableAdjustments: .focusAndExposure
    )

    private static let backOptics = LensOptics(
        lenses: [
            LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: 13),
            LensOptics.PhysicalLens(deviceFactor: 2, cropFactors: [2], focalLength: 24),
            LensOptics.PhysicalLens(deviceFactor: 8, cropFactors: [2], focalLength: 100)
        ],
        displayMultiplier: 0.5,
        maximumDeviceFactor: 240,
        recommendedMaximumDeviceFactor: nil
    )

    private static let frontOptics = LensOptics(
        lenses: [LensOptics.PhysicalLens(deviceFactor: 1, cropFactors: [], focalLength: nil)],
        displayMultiplier: 1,
        maximumDeviceFactor: 5,
        recommendedMaximumDeviceFactor: nil
    )

    private static let logger = Logger.camera("SimulatedCameraService")

    /// Like the device, the camera has Live Photo and RAW only where the flow can use them. A camera that has not
    /// been asked for gets the answer of `authorizationOnRequest` when it is, granted unless said otherwise. The
    /// first `startFailureCount` starts fail, as a camera does that another app holds.
    init(
        scene: SimulatedScene,
        features: PhotoCaptureFeatures = .all,
        backPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneBackPhotoCapabilities,
        frontPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneFrontPhotoCapabilities,
        dualPhotoCapabilities: PhotoCaptureCapabilities = SimulatedCameraService.iPhoneDualPhotoCapabilities,
        isDualCameraSupported: Bool = true,
        isAuthorizationDetermined: Bool = true,
        authorizationOnRequest: CameraAuthorization = .authorized,
        startFailureCount: Int = 0
    ) {
        self.scene = scene
        self.isAuthorizationDetermined = isAuthorizationDetermined
        self.authorizationOnRequest = authorizationOnRequest
        self.backPhotoCapabilities = backPhotoCapabilities.narrowed(to: features)
        self.frontPhotoCapabilities = frontPhotoCapabilities.narrowed(to: features)
        self.dualPhotoCapabilities = dualPhotoCapabilities.narrowed(to: features)
        self.isDualCameraSupported = isDualCameraSupported
        remainingStartFailures = startFailureCount
    }

    var cameraPositions: [CameraPosition] {
        [.back, .front]
    }

    var isAuthorized: Bool {
        isAuthorizationDetermined && authorizationOnRequest == .authorized
    }

    func requestAuthorization() async -> CameraAuthorization {
        isAuthorizationDetermined = true
        return authorizationOnRequest
    }

    func start(position: CameraPosition) async throws -> CameraCapabilities {
        guard remainingStartFailures == 0 else {
            remainingStartFailures -= 1
            throw CameraServiceError.cannotUseCamera("The simulated camera does not start")
        }
        let optics = position == .back ? Self.backOptics : Self.frontOptics
        let started = position == .back ? backPhotoCapabilities : frontPhotoCapabilities
        photoCapabilities = started
        singlePosition = position
        dualMainPosition = nil
        runNewSession()
        refreshPreviews()
        return LensCatalog.capabilities(position: position, optics: optics)
    }

    func startDualCamera(main: CameraPosition) async throws -> CameraCapabilities {
        guard isDualCameraSupported else {
            throw CameraServiceError.dualCameraUnavailable("The simulated device has no dual camera")
        }
        photoCapabilities = main == .back ? dualPhotoCapabilities : frontPhotoCapabilities
        dualMainPosition = main
        runNewSession()
        refreshPreviews()
        let optics = main == .back ? Self.backOptics : Self.frontOptics
        return LensCatalog.capabilities(position: main, optics: optics)
    }

    /// The simulated camera is never interrupted and has no Camera Control, so it reports no event.
    func setEventHandler(_ handler: @escaping @MainActor (CameraSessionEvent) -> Void) {}

    /// The simulated camera has no Camera Control.
    func selectCaptureControlLens(at index: Int) {}

    /// The flat preview and the flat photos look the same at every zoom, exposure bias and focus point.
    func setExposureBias(_ bias: Double) {}

    /// The flat scene never needs the flash and the flash is always available, which the flow assumes until a camera
    /// reports otherwise, so the simulated camera reports neither.
    func monitorFlashScene(for flashMode: CameraFlowFlashMode, format: CameraFlowPhotoFormat) {}

    func stop() {
        isRunning = false
        sessionNumber += 1
    }

    private func runNewSession() {
        isRunning = true
        sessionNumber += 1
    }

    func setZoom(_ factor: CGFloat) {}

    func rampZoom(to factor: CGFloat, rate: Float) {}

    func focus(atDevicePoint point: CGPoint) {}

    func resetFocus() {}

    /// The flat picture has nothing to adjust to, so a camera that runs settles into the lock at once, and a stopped
    /// one does not lock.
    func lockFocusAndExposure(atDevicePoint point: CGPoint) async -> Bool {
        isRunning
    }

    func unlockFocusAndExposure() {}

    func capturePhoto(_ request: PhotoCaptureRequest) async throws -> CapturedPhoto {
        guard isRunning, let photoCapabilities else {
            throw CameraServiceError.notRunning
        }
        let session = sessionNumber
        let usesHEVC = request.format == .heif && photoCapabilities.encodesHEVC && Self.canEncodeHEVC
        let encoding: PhotoCaptureEncoding = switch request.format {
        case .heif: usesHEVC ? .heif : .jpeg
        case .raw: .appleProRAW
        }
        let typeIdentifier = usesHEVC ? Self.heicType : Self.jpegType
        let shot = try await Self.encode(
            mainPhotoFile(typeIdentifier: typeIdentifier),
            circle: dualMainPosition.map { circleShot(main: $0, typeIdentifier: typeIdentifier) }
        )
        guard session == sessionNumber else {
            throw CameraServiceError.notRunning
        }
        return CapturedPhoto(
            imageData: shot.imageData,
            encoding: encoding,
            livePhotoMovieURL: request.isLivePhotoEnabled ? try writeLivePhotoMovie() : nil,
            location: request.location,
            circleCameraFrame: shot.circleCameraFrame
        )
    }

    /// The photo file of the camera in the circle of the dual camera, and whether the viewfinder shows the camera
    /// beside it mirrored.
    private struct CircleShot: Sendable {
        let file: SimulatedPhotoFile
        let isViewfinderMirrored: Bool
    }

    /// The files of a shot, encoded off the main actor: the photo, and the frame of the circle's camera.
    @concurrent
    private static func encode(
        _ mainFile: SimulatedPhotoFile,
        circle: CircleShot?
    ) async throws -> (imageData: Data, circleCameraFrame: CircleCameraFrame?) {
        let circleCameraFrame = try circle.map { circle in
            CircleCameraFrame(
                imageData: try circle.file.encoded(),
                isViewfinderMirrored: circle.isViewfinderMirrored,
                viewfinderQuarterTurns: 0
            )
        }
        return (try mainFile.encoded(), circleCameraFrame)
    }

    func makePreview() -> any CameraPreview {
        let preview = SimulatedPreview(color: sceneColor)
        mainPreviews.append(WeakPreview(preview: preview))
        refreshPreviews()
        return preview
    }

    func makeCirclePreview() -> any CameraPreview {
        let preview = SimulatedPreview(color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        circlePreviews.append(WeakPreview(preview: preview))
        refreshPreviews()
        return preview
    }

    private var sceneColor: CGColor {
        switch scene {
        case .black:
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        case let .color(red, green, blue):
            CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        }
    }

    private static let jpegType = "public.jpeg"
    private static let heicType = "public.heic"

    private static var canEncodeHEVC: Bool {
        guard let types = CGImageDestinationCopyTypeIdentifiers() as? [String] else { return false }
        return types.contains(heicType)
    }

    /// An empty stand-in for the paired movie, in the package's directory of movies like the device's.
    private func writeLivePhotoMovie() throws -> URL {
        let url = try CaptureFileStore.temporaryMovieURL(parent: temporaryDirectory)
        do {
            try Data().write(to: url)
        } catch {
            // The localized description names the movie without its folders, so the text holds no path.
            let reason = error.localizedDescription
            throw CameraServiceError.captureFailed("Cannot write the simulated Live Photo movie: \(reason)")
        }
        return url
    }
}

// MARK: - The dual camera

extension SimulatedCameraService {

    private func picture(of position: CameraPosition) -> SimulatedDualPicture {
        SimulatedDualPicture(background: position == .back ? sceneColor : SimulatedDualPicture.frontColor)
    }

    /// The picture of the camera in the viewfinder, nil for the flat scene of the back camera alone.
    private var mainPicture: SimulatedDualPicture? {
        if let dualMainPosition {
            return picture(of: dualMainPosition)
        }
        return singlePosition == .front ? SimulatedDualPicture(background: sceneColor) : nil
    }

    /// The picture of the camera in the viewfinder as the camera saw it, or the flat scene of the back camera alone.
    private func mainPhotoFile(typeIdentifier: String) -> SimulatedPhotoFile {
        guard let mainPicture else {
            return SimulatedPhotoFile(
                picture: .flat(sceneColor),
                typeIdentifier: typeIdentifier,
                lensModel: Self.lensModel(of: .back)
            )
        }
        return SimulatedPhotoFile(
            picture: .dualCamera(mainPicture),
            typeIdentifier: typeIdentifier,
            lensModel: Self.lensModel(of: dualMainPosition ?? singlePosition)
        )
    }

    /// The photo of the camera in the circle of the pair with `main` in the viewfinder, as taken with the phone
    /// upright: never mirrored.
    private func circleShot(main: CameraPosition, typeIdentifier: String) -> CircleShot {
        let position = main.flipped
        let file = SimulatedPhotoFile(
            picture: .dualCamera(picture(of: position)),
            typeIdentifier: typeIdentifier,
            lensModel: Self.lensModel(of: position)
        )
        return CircleShot(file: file, isViewfinderMirrored: main.isMirroredOnScreen)
    }

    private static func lensModel(of position: CameraPosition) -> String {
        switch position {
        case .back: "CameraFlow simulated back camera"
        case .front: "CameraFlow simulated front camera"
        }
    }

    /// Puts on every live preview what its camera sees now. A picture that cannot be rendered is logged and its
    /// preview shows the flat colour of the picture.
    private func refreshPreviews() {
        mainPreviews.removeAll { $0.preview == nil }
        circlePreviews.removeAll { $0.preview == nil }
        let circlePosition = dualMainPosition?.flipped
        let mainPosition = dualMainPosition ?? singlePosition
        for reference in mainPreviews {
            guard let preview = reference.preview else { continue }
            if let mainPicture {
                show(mainPicture, isMirrored: mainPosition.isMirroredOnScreen, in: preview)
            } else {
                preview.show(color: sceneColor)
            }
        }
        for reference in circlePreviews {
            guard let preview = reference.preview, let circlePosition else { continue }
            show(picture(of: circlePosition), isMirrored: circlePosition.isMirroredOnScreen, in: preview)
        }
    }

    private func show(_ picture: SimulatedDualPicture, isMirrored: Bool, in preview: SimulatedPreview) {
        do {
            let image = try picture.previewImage(isMirrored: isMirrored)
            preview.show(picture: image)
        } catch {
            Self.logger.error("Cannot render a simulated preview", cause: error)
            preview.show(color: picture.background)
        }
    }
}
