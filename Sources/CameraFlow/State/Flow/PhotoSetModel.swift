//
//  PhotoSetModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Observation
import os

/// The photos of one flow, from the camera and from the photo library, in the order they were added.
///
/// The set owns the files of every photo it holds. `handOver()` passes the photos to the receiver, exactly once,
/// and their files with them, the copies of the photos with a drawing among them. The thumbnail of such a photo
/// is made from its copy. A drawing goes over the copy with the second camera's circle of a dual capture, which
/// the copy with the drawing then replaces. Everything else is deleted: a photo that is removed, every photo of a
/// set that is discarded, and whatever arrives once the set has ended or is full. While the set is being handed
/// over it takes no change, and a hand-over that has begun is never undone: a set discarded meanwhile is still
/// handed over.
///
/// When the photos are saved at the hand-over, nothing reaches the photo library while the set is open. The
/// hand-over saves the camera photos still in the set, while saving is on: the original, and for a photo with a
/// drawing the copy with it as the edit of the same asset. A photo that is removed and a set that is discarded are
/// never saved. When a save fails at the first check mark that saved, the set stays open and the notice says why; the
/// next check mark saves the photos the library has not taken and hands the set over whatever becomes of them.
///
/// When the photos are saved after each shot, a camera photo that arrives while saving is on is saved at once, as the
/// camera took it, and the hand-over waits for the saves still running and reports them. A removed photo and a
/// discarded set keep their saved copies: their files are deleted only once their save has ended, since the save
/// reads them. A failed save leaves the photo in the set and says so in the notice.
///
/// The app is kept running in the background for the hand-over and for a save after a shot, so leaving the app at
/// once loses neither.
@MainActor
@Observable
final class PhotoSetModel {
    private(set) var photos: [FlowPhoto] = []
    /// How many picks from the photo library are still loading.
    private(set) var pendingImportCount = 0
    /// What the last import left out or why the last hand-over did not happen, nil once the set changes again.
    private(set) var notice: PhotoSetNotice?
    /// True while the copies of the photos with a drawing are being written and the photos saved for the hand-over.
    private(set) var isHandingOver = false
    /// True once the set was handed over or discarded.
    private(set) var hasEnded = false
    /// The photos saved right after their shot, and what became of them.
    let shutterSaves = ShutterLibrarySaves()
    let limit: CameraFlowPhotoLimit
    /// What became of the camera photos saved at a check mark that left the set open, by photo.
    @ObservationIgnored var acceptedSaves: [UUID: AcceptedSave] = [:]
    /// True once a save at a check mark failed and the set stayed open to say so. The next check mark hands the set
    /// over whatever its saves return.
    @ObservationIgnored private var hasShownAcceptedSaveFailure = false

    @ObservationIgnored let fileStore: CaptureFileStore
    /// The quality a pick from the photo library is brought to, with the output it makes of the app's.
    @ObservationIgnored private let quality: PhotoQualityModel
    @ObservationIgnored let librarySaving: PhotoLibrarySavingModel?
    @ObservationIgnored let renderer: any MarkupRenderer
    /// Keeps the app running until the hand-over and every save after a shot have ended.
    @ObservationIgnored let backgroundWork: any BackgroundWork
    @ObservationIgnored private let onHandOver: ([CameraFlowPhoto]) -> Void
    /// True when the set was discarded while it was being handed over, for a hand-over that leaves it open.
    @ObservationIgnored private var isDiscardPending = false
    /// Told when a photo of the camera is in the set, while the shot that brought it is still ending.
    @ObservationIgnored var onCameraPhotoAdded: (() -> Void)?
    /// Told when a hand-over begins and ends, and asked whether its set reaches anyone: the receiver of a controller
    /// that presents the flow. Nil where `onHandOver` alone receives the set, which then always reaches it.
    @ObservationIgnored var handOverObserver: (any PhotoSetHandOverObserver)?

    static let logger = Logger.camera("PhotoSetModel")

    init(
        limit: CameraFlowPhotoLimit,
        fileStore: CaptureFileStore,
        quality: PhotoQualityModel,
        librarySaving: PhotoLibrarySavingModel?,
        renderer: any MarkupRenderer,
        backgroundWork: any BackgroundWork,
        onHandOver: @escaping ([CameraFlowPhoto]) -> Void
    ) {
        self.limit = limit
        self.fileStore = fileStore
        self.quality = quality
        self.librarySaving = librarySaving
        self.renderer = renderer
        self.backgroundWork = backgroundWork
        self.onHandOver = onHandOver
    }

    var count: Int {
        photos.count
    }

    var isEmpty: Bool {
        photos.isEmpty
    }

    /// Whether a camera photo of the set exists nowhere else: one that the photo library did not take, right after
    /// its shot or at a check mark that left the set open. A photo whose save still runs counts as unsaved until the
    /// library took it.
    var hasUnsavedCameraPhotos: Bool {
        photos.contains { photo in
            photo.source == .camera && !shutterSaves.isSaved(photo.id) && !isSavedAtCheckMark(photo.id)
        }
    }

    var isImporting: Bool {
        pendingImportCount > 0
    }

    /// How many more photos the set takes, nil without a limit. A pick that is still loading holds its place.
    var remainingCapacity: Int? {
        guard case let .maximum(maximum) = limit else { return nil }
        return max(maximum - photos.count - pendingImportCount, 0)
    }

    var isFull: Bool {
        remainingCapacity == 0
    }

    /// Whether the set takes another photo beside the photos on their way into it from the shutter.
    func hasRoom(besides photosInFlight: Int) -> Bool {
        guard let remainingCapacity else { return true }
        return remainingCapacity > photosInFlight
    }

    /// Whether the set can change now: it has not ended and is not being handed over.
    private var takesChanges: Bool {
        !hasEnded && !isHandingOver
    }

    // MARK: - Adding

    /// Keeps a capture the camera delivered, or deletes its files when the set takes no change or is full.
    func add(_ capture: CameraCapture) {
        guard takesChanges, !isFull else {
            Self.logger.info("A capture arrived at a set that takes no more photos and was deleted")
            CaptureFileStore.discardFiles(of: capture)
            fileStore.removeDirectoryIfEmpty()
            return
        }
        notice = nil
        let photo = FlowPhoto(capture: capture)
        photos.append(photo)
        if let librarySaving, librarySaving.moment == .afterEachPhoto, librarySaving.isOn {
            shutterSaves.save(photo, to: librarySaving, keptRunningBy: backgroundWork) { [weak self] save in
                self?.shutterSaveEnded(save)
            }
        }
        onCameraPhotoAdded?()
    }

    /// A failed save after a shot leaves the photo in the set and says so.
    private func shutterSaveEnded(_ save: CameraFlowPhotoLibrarySave) {
        guard case let .failed(failure) = save else { return }
        Self.logger.error("A photo was not saved to the library after its shot")
        if !hasEnded {
            notice = .librarySaveFailed(failure)
        }
    }

    /// Adds the picks from the photo library in their order, each as its file arrives.
    ///
    /// Picks beyond what the set still takes are left out, and a pick whose file cannot be loaded is skipped: the
    /// notice says so in both cases.
    func importPicks(_ picks: [any PhotoLibraryPick]) async {
        guard takesChanges else { return }
        let admitted = Array(picks.prefix(remainingCapacity ?? picks.count))
        notice = nil
        pendingImportCount += admitted.count
        let pipeline = LibraryPhotoPipeline(store: fileStore, output: quality.photoLibraryOutput)
        var failedCount = 0
        var isOutOfSpace = false
        for pick in admitted {
            defer { pendingImportCount -= 1 }
            guard !hasEnded else { continue }
            do {
                let libraryPhoto = try await pipeline.process(pick)
                add(libraryPhoto)
            } catch {
                failedCount += 1
                isOutOfSpace = isOutOfSpace || StorageFailure.isOutOfSpace(error)
                Self.logger.error("Cannot load a photo from the library", cause: error)
                if hasEnded {
                    fileStore.removeDirectoryIfEmpty()
                }
            }
        }
        guard !hasEnded else { return }
        if isOutOfSpace {
            notice = .notEnoughStorage
        } else if failedCount > 0 {
            notice = .importFailed(count: failedCount)
        } else if case let .maximum(maximum) = limit, admitted.count < picks.count {
            notice = .limitReached(maximum)
        }
    }

    /// Keeps a photo whose files have arrived, or deletes them when the set ended while they were loading.
    private func add(_ libraryPhoto: LibraryPhoto) {
        guard !hasEnded else {
            libraryPhoto.fileURLs.forEach(CaptureFileStore.discard)
            fileStore.removeDirectoryIfEmpty()
            return
        }
        photos.append(FlowPhoto(libraryPhoto: libraryPhoto))
    }

    // MARK: - Removing

    /// Takes a photo out of the set and deletes its files.
    func remove(_ photo: FlowPhoto) {
        guard takesChanges, let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        notice = nil
        deleteFiles(of: photos.remove(at: index))
    }

    /// Deletes the files of a photo that is not handed over: at once, or once the save that reads them has ended.
    private func deleteFiles(of photo: FlowPhoto) {
        let urls = photo.fileURLs
        guard let save = shutterSaves.running(photo.id) else {
            urls.forEach(CaptureFileStore.discard)
            return
        }
        Task { [fileStore] in
            _ = await save.value
            urls.forEach(CaptureFileStore.discard)
            fileStore.removeDirectoryIfEmpty()
        }
    }

    // MARK: - Drawing

    /// Keeps what was drawn on a photo of the set. Nil takes the drawing off the photo.
    func setDrawing(_ drawing: MarkupDrawing?, ofPhoto photoIdentifier: UUID) {
        guard takesChanges, let index = photos.firstIndex(where: { $0.id == photoIdentifier }) else { return }
        notice = nil
        photos[index].drawing = drawing
    }

    // MARK: - Ending

    /// Hands every photo to the receiver, which owns their files from then on. A photo with a drawing comes with
    /// its copy, which is written first. Then, while saving is on, every camera photo is saved to the photo library,
    /// one after the other, and comes with what became of it: a refused or failed save loses nothing.
    ///
    /// When a copy cannot be written, the set is not handed over, nothing is saved, and the notice says so, naming a
    /// device without room. The first time a save at the check mark fails, the set is not handed over either and the
    /// notice says why. Later calls, a call while the set is being handed over and a call while a pick is still
    /// loading do nothing.
    ///
    /// A hand-over that has begun runs to its end whatever happens to the screen meanwhile, and the app is kept
    /// running for it in the background. A set discarded while it runs is handed over all the same, and discarded
    /// only when the hand-over leaves it open. A set that reaches nobody, as the observer says, is deleted instead.
    func handOver() async {
        guard takesChanges, !isImporting else { return }
        isHandingOver = true
        notice = nil
        handOverObserver?.handOverBegan()
        await backgroundWork.run(named: "CameraFlow hand-over") {
            await writeCopiesAndHandOver()
        }
        isHandingOver = false
        if isDiscardPending {
            discard()
        }
        handOverObserver?.handOverEnded()
    }

    private func writeCopiesAndHandOver() async {
        let copies: [UUID: MarkedUpCopy]
        do {
            copies = try await writeCopies()
        } catch {
            Self.logger.error("Cannot write the copy of a photo with its drawing", cause: error)
            notice = (error as? MarkupFailure) == .notEnoughStorage ? .notEnoughStorage : .copyFailed
            return
        }
        let saves = await saveToLibrary(copies: copies)
        if let failure = acceptedSaveFailureToShow(in: saves) {
            Self.logger.error("A photo was not saved to the library at the check mark, so the set stays open")
            copies.values.forEach { CaptureFileStore.discard($0.fileURL) }
            notice = .librarySaveFailed(failure)
            return
        }
        hasEnded = true
        let handedOver = photos.map { CameraFlowPhoto($0, markedUpCopy: copies[$0.id], photoLibrarySave: saves[$0.id]) }
        let replacedCopies = photos.filter { copies[$0.id] != nil }.compactMap(\.dualCameraCopy?.url)
        replacedCopies.forEach(CaptureFileStore.discard)
        photos.compactMap(\.libraryFileURL).forEach(CaptureFileStore.discard)
        photos = []
        if let handOverObserver, !handOverObserver.receivesSets {
            deleteUnreceived(handedOver)
            return
        }
        fileStore.releaseToReceiver()
        onHandOver(handedOver)
    }

    /// The failure of a save at the check mark that the set stays open to show: the first of the first check mark
    /// whose save failed. Nil for a later check mark, which hands the set over whatever its saves return, and for a
    /// set discarded meanwhile, whose screen is gone: it is handed over all the same.
    private func acceptedSaveFailureToShow(
        in saves: [UUID: CameraFlowPhotoLibrarySave]
    ) -> CameraFlowPhotoLibrarySaveFailure? {
        guard !hasShownAcceptedSaveFailure, !isDiscardPending, librarySaving?.moment == .whenSetAccepted else {
            return nil
        }
        let failures = photos.compactMap { photo -> CameraFlowPhotoLibrarySaveFailure? in
            guard case let .failed(failure) = saves[photo.id] else { return nil }
            return failure
        }
        guard let failure = failures.first else { return nil }
        hasShownAcceptedSaveFailure = true
        return failure
    }

    /// Ends the set without a hand-over and deletes every file it holds. Later calls, and a call after the
    /// hand-over, do nothing. A set that is being handed over is left to its hand-over, and is discarded after it
    /// only when that leaves the set open.
    func discard() {
        guard !hasEnded else { return }
        guard !isHandingOver else {
            isDiscardPending = true
            return
        }
        hasEnded = true
        notice = nil
        let discarded = photos
        photos = []
        discarded.forEach(deleteFiles)
        fileStore.removeDirectoryIfEmpty()
    }
}

extension PhotoSetModel: CaptureAdmission {

    /// The limit counts the photos on their way from the shutter, so the set never gets one more than it takes.
    func captureRefusal(photosInFlight: Int) -> CameraServiceError? {
        guard case let .maximum(maximum) = limit, !hasRoom(besides: photosInFlight) else { return nil }
        return .captureLimitReached(maximum)
    }
}
