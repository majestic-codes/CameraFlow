//
//  PhotoReviewModel.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Observation

/// The review of the set: which photo it shows, the pictures it shows its photos with, and the question before a
/// photo is deleted.
@MainActor
@Observable
final class PhotoReviewModel {
    /// The photo the review shows, nil before the review first opens and once the set has no photo left.
    private(set) var currentPhotoIdentifier: UUID?
    /// What the delete dialog asks about, nil while it is not shown.
    private(set) var deleteConfirmation: DeleteConfirmation?

    let images: ReviewImageModel
    @ObservationIgnored private let photoSet: PhotoSetModel

    init(photoSet: PhotoSetModel, renderer: any MarkupRenderer) {
        self.photoSet = photoSet
        images = ReviewImageModel(renderer: renderer)
    }

    // MARK: - The current photo

    private var currentIndex: Int? {
        photoSet.photos.firstIndex { $0.id == currentPhotoIdentifier }
    }

    var currentPhoto: FlowPhoto? {
        currentIndex.map { photoSet.photos[$0] }
    }

    /// Where the current photo stands in the set.
    var currentPosition: PhotoPosition? {
        currentIndex.map { PhotoPosition(number: $0 + 1, count: photoSet.count) }
    }

    /// The current photo with the one before it and the one after it: the pages one swipe reaches.
    var nearbyPhotos: [FlowPhoto] {
        guard let currentIndex else { return [] }
        let photos = photoSet.photos
        let nearest = max(currentIndex - 1, 0)...min(currentIndex + 1, photos.count - 1)
        return Array(photos[nearest])
    }

    /// Shows the photo that was added last.
    func showLastPhoto() {
        currentPhotoIdentifier = photoSet.photos.last?.id
    }

    /// Shows a photo of the set: the page a swipe settled on, or the tile that was tapped.
    func show(_ photoIdentifier: UUID) {
        guard photoSet.photos.contains(where: { $0.id == photoIdentifier }) else { return }
        currentPhotoIdentifier = photoIdentifier
    }

    // MARK: - Deleting

    /// The trash: asks before the current photo is deleted.
    func requestDelete() {
        guard let currentPhoto else { return }
        deleteConfirmation = DeleteConfirmation(photo: currentPhoto)
    }

    func cancelDelete() {
        deleteConfirmation = nil
    }

    /// The destructive answer of the delete dialog: takes the photo it asked about out of the set, with its files.
    /// The review goes on with the photo that followed it, or with the one before it after the last photo.
    func confirmDelete(_ confirmation: DeleteConfirmation) {
        deleteConfirmation = nil
        guard let index = photoSet.photos.firstIndex(where: { $0.id == confirmation.photoIdentifier }) else { return }
        photoSet.remove(photoSet.photos[index])
        guard currentPhotoIdentifier == confirmation.photoIdentifier else { return }
        let remaining = photoSet.photos
        // The photo that followed the deleted one has taken its index.
        currentPhotoIdentifier = index < remaining.count ? remaining[index].id : remaining.last?.id
    }
}
