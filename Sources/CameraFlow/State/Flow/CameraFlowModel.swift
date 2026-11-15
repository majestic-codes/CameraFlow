//
//  CameraFlowModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Observation

/// The flow screen above its camera, its set, its review and the drawing on a photo of the review: the mode, what
/// the bottom bar and the library buttons may do now, what crosses between the four, and the two ways out.
@MainActor
@Observable
final class CameraFlowModel<Canvas: MarkupCanvas> {
    private(set) var mode = CameraFlowMode.shooting
    /// Whether the exit alert is up.
    private var isExitRequested = false
    /// Whether the sheet of the photo library is up. The sheet turns it off itself when it closes.
    var isLibraryPresented = false

    let camera: PhotoCameraModel
    let photoSet: PhotoSetModel
    let review: PhotoReviewModel
    let markup: PhotoMarkupModel<Canvas>
    /// Whether the flow offers the photo library at all.
    let isLibraryPickerEnabled: Bool
    /// Whether the user accepts the set or the flow ends by itself after one photo.
    let completion: CameraFlowCompletion
    @ObservationIgnored private let haptics: any CameraHaptics
    @ObservationIgnored private let onExit: () -> Void

    init(
        camera: PhotoCameraModel,
        photoSet: PhotoSetModel,
        renderer: any MarkupRenderer,
        openCanvas: @escaping MarkupCanvasOpener<Canvas>,
        isLibraryPickerEnabled: Bool,
        completion: CameraFlowCompletion,
        haptics: any CameraHaptics,
        onExit: @escaping () -> Void
    ) {
        self.camera = camera
        self.photoSet = photoSet
        let review = PhotoReviewModel(photoSet: photoSet, renderer: renderer)
        self.review = review
        markup = PhotoMarkupModel<Canvas>(photoSet: photoSet, images: review.images, openCanvas: openCanvas)
        self.isLibraryPickerEnabled = isLibraryPickerEnabled
        self.completion = completion
        self.haptics = haptics
        self.onExit = onExit
        if completion == .afterOnePhoto {
            photoSet.onCameraPhotoAdded = { [weak self] in
                Task { await self?.finishAfterOnePhoto() }
            }
        }
        camera.onCaptureEnded = { [weak self] in
            self?.captureEnded()
        }
    }

    // MARK: - Upright elements

    /// The turn of the upright elements of the chrome both modes share, of the review and of the drawing: the
    /// camera's in the shooting mode, and none in the review, which stands upright in the interface.
    var elementRotation: CameraElementRotation {
        let rotation = camera.elementRotation
        return switch mode {
        case .shooting: rotation
        case .review: rotation.turned(to: .portrait)
        }
    }

    // MARK: - The notice line

    /// What the line over the viewfinder says, nil when nothing: in the shooting mode the camera first, then the
    /// set. In the review the camera is stopped, so the drawing mode speaks first and the set after it.
    var notice: FlowNotice? {
        let setNotice = photoSet.notice.map(FlowNotice.photoSet)
        return switch mode {
        case .shooting: camera.notice.map(FlowNotice.camera) ?? setNotice
        case .review: markup.notice.map(FlowNotice.markup) ?? setNotice
        }
    }

    // MARK: - What is enabled

    /// True while the check mark writes the copies of the photos with a drawing: nothing else happens meanwhile.
    var isHandingOver: Bool {
        photoSet.isHandingOver
    }

    /// What the exit alert asks about, nil while it is not shown: the set as it is now and the photos the camera took
    /// that are on their way into it, so a photo that lands while the alert is up stays counted and one that fails
    /// no longer is.
    var exitConfirmation: ExitConfirmation? {
        guard isExitRequested else { return nil }
        let photosOnTheirWay = camera.firedPhotosInFlight
        return ExitConfirmation(
            photoCount: photoSet.count + photosOnTheirWay,
            hasCameraPhotos: photosOnTheirWay > 0 || photoSet.hasUnsavedCameraPhotos
        )
    }

    /// The shutter takes photos until the set is full, counting the photos on their way into it, or has ended, and
    /// only while the camera runs: none before it started, while it has failed or while it is paused. A running
    /// self-timer keeps the shutter, so that a tap can stop it.
    var canShoot: Bool {
        guard !photoSet.hasEnded, !isHandingOver, camera.isRunning else { return false }
        return camera.isCountingDown || photoSet.hasRoom(besides: camera.photosInFlight)
    }

    /// The review needs a photo to show. It stops the camera, so it waits for every photo on its way.
    var canShowReview: Bool {
        !photoSet.isEmpty && !camera.isCapturing && !isHandingOver
    }

    /// The camera comes back unless a photo is being drawn on, the set is being handed over or has ended.
    var canShowShooting: Bool {
        !markup.isOpen && !isHandingOver && !photoSet.hasEnded
    }

    /// The set is handed over whole: not while a photo is on its way, a pick is still loading or a photo is being
    /// drawn on.
    var canAccept: Bool {
        !photoSet.isEmpty && !photoSet.isImporting && !camera.isCapturing && !markup.isOpen && !isHandingOver
    }

    /// The library opens while the set has room and nothing else is on its way into it, so the sheet can offer
    /// exactly what is left of the limit.
    var canOpenLibrary: Bool {
        guard isLibraryPickerEnabled, !isHandingOver, !photoSet.hasEnded else { return false }
        return !photoSet.isFull && !photoSet.isImporting && !camera.isCapturing
    }

    /// Whether a press of the Camera Control or a volume button takes a photo now: only while the camera is what
    /// the user looks at, so not under the introduction either.
    var acceptsCaptureButtons: Bool {
        guard mode == .shooting, !isLibraryPresented, !isExitRequested, !isHandingOver else { return false }
        return !photoSet.hasEnded && camera.acceptsCaptureButtons
    }

    // MARK: - Modes

    /// Opens the review on the last photo added and stops the camera.
    func showReview() {
        guard mode == .shooting, canShowReview else { return }
        mode = .review
        review.showLastPhoto()
        camera.stop()
    }

    /// Returns to the camera and starts it again as it was.
    func showShooting() async {
        guard mode == .review, canShowShooting else { return }
        mode = .shooting
        review.images.releaseAll()
        await camera.resume()
        // The review may have been opened again while the camera was starting.
        if mode == .review {
            camera.stop()
        }
    }

    /// A finger came down on the mode switch: the haptics its release may play are readied.
    func modeSwitchTouched() {
        haptics.prepare(for: .modeSelected)
        haptics.prepare(for: .modeRefused)
    }

    /// Moves to a mode the user chose on the switch, with a tick when the mode changes. A mode that cannot be
    /// shown now is left alone, and the review that cannot be shown is refused with a light haptic.
    func select(_ target: CameraFlowMode) async {
        guard target != mode else { return }
        switch target {
        case .review:
            guard canShowReview else {
                haptics.play(.modeRefused)
                return
            }
            haptics.play(.modeSelected)
            showReview()
        case .shooting:
            guard canShowShooting else { return }
            haptics.play(.modeSelected)
            await showShooting()
        }
    }

    // MARK: - Photo library

    /// The most photos the library sheet lets the user pick, nil for any number.
    var librarySelectionLimit: Int? {
        photoSet.remainingCapacity
    }

    func openLibrary() {
        guard canOpenLibrary else { return }
        isLibraryPresented = true
    }

    /// Adds what the library sheet confirmed to the set. The flow stays in the mode it is in: a pick from the camera
    /// leaves the camera on the screen. Once the picks are in, the last of them is the photo the review is on, so
    /// the review opens with it, unless a photo of the review is being drawn on: the review stays on it. What the
    /// camera said before goes, so it does not stand before what the set says about the picks.
    func importPicks(_ picks: [any PhotoLibraryPick]) async {
        camera.clearNotices()
        let knownPhotos = Set(photoSet.photos.map(\.id))
        await photoSet.importPicks(picks)
        if photoSet.photos.contains(where: { !knownPhotos.contains($0.id) }) {
            if !markup.isOpen {
                review.showLastPhoto()
            }
            await finishAfterOnePhoto()
        }
    }

    // MARK: - Review

    /// The destructive answer of the delete dialog. A review left without a photo gives way to the camera.
    func deletePhoto(confirmedBy confirmation: DeleteConfirmation) async {
        review.confirmDelete(confirmation)
        if photoSet.isEmpty {
            await showShooting()
        }
    }

    /// The Markup button of the review: opens the drawing on the photo the review shows, over its picture at the
    /// size of the screen, which is decoded first where the review has not prepared it yet. A review that moved on
    /// meanwhile opens nothing.
    func startMarkup() async {
        guard mode == .review, !isHandingOver, !markup.isOpen, let photo = review.currentPhoto else { return }
        let picture = await review.images.screenImage(of: photo)
        guard mode == .review, !isHandingOver, review.currentPhoto?.id == photo.id else { return }
        markup.start(on: photo, picture: picture)
    }

    // MARK: - Ways out

    /// The check mark: hands the set over to the app, with the copies of the photos with a drawing. The camera of a
    /// set that was handed over is closed: a flow the app leaves on screen takes no more photos.
    func accept() async {
        guard canAccept else { return }
        camera.clearNotices()
        await photoSet.handOver()
        if photoSet.hasEnded {
            camera.close()
        }
    }

    /// Hands the set over by itself once it has its photo, in a flow that ends after one photo. It waits for the
    /// shot that brought the photo to end, as the check mark does, and for the answer of the exit alert while it asks.
    func finishAfterOnePhoto() async {
        guard completion == .afterOnePhoto, !photoSet.isEmpty, !isExitRequested else { return }
        await accept()
    }

    /// The cross, its key and the escape gesture: a flow that leaves no photo behind is left at once, and one with
    /// photos in the set or on their way into it asks first, since leaving deletes them.
    func requestExit() {
        guard !photoSet.hasEnded, !isHandingOver else { return }
        guard leavesPhotosBehind else {
            exit()
            return
        }
        isExitRequested = true
    }

    /// The answer of the exit alert that stays. In a flow that ends after one photo, the photo that landed while the
    /// alert asked is handed over now.
    func cancelExit() {
        isExitRequested = false
        guard completion == .afterOnePhoto else { return }
        Task { [weak self] in
            await self?.finishAfterOnePhoto()
        }
    }

    /// Whether leaving now leaves photos behind: the set's own, and the photos the camera took that are on their way
    /// into it.
    private var leavesPhotosBehind: Bool {
        !photoSet.isEmpty || camera.firedPhotosInFlight > 0
    }

    /// A press of the shutter ended. An exit alert that asked only about photos on their way, all of which failed,
    /// has nothing left to ask about: it closes, and the flow stays with what the camera said.
    private func captureEnded() {
        guard isExitRequested, !leavesPhotosBehind else { return }
        isExitRequested = false
    }

    /// The destructive answer of the exit alert.
    func confirmExit() {
        guard !photoSet.hasEnded, !isHandingOver else { return }
        isExitRequested = false
        exit()
    }

    /// Leaves the flow: the set is deleted and the camera closed, with its self-timer and the location, so nothing
    /// is taken once the user left.
    private func exit() {
        photoSet.discard()
        camera.close()
        onExit()
    }
}
