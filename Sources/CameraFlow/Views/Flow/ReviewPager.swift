//
//  ReviewPager.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The photos of the set as pages in the frame of the 4:3 viewfinder: a swipe turns the page, and the page of the
/// current photo zooms until the page is turned. What is drawn on a photo lies over it and zooms with it. The small
/// thumbnail of a photo stands in until the photo is decoded for the screen, at the size the page has now. The pages
/// show within the frame of the photo, and in a right-to-left language the set runs from the right.
///
/// While a photo is drawn on, the pages stand still at their fitted size, and the drawing of that photo is the
/// canvas's to show.
struct ReviewPager: View {
    @Environment(\.flowLocalization) private var localization
    let review: PhotoReviewModel
    let photoSet: PhotoSetModel
    let markup: EmbeddedPhotoMarkupModel
    let layout: CameraScreenLayout

    @Environment(\.displayScale) private var displayScale
    @State private var zoomedPhotoIdentifier: UUID?
    /// The page the scroll view stands on, nil while a finger moves it between two pages. The scroll view writes
    /// it, so it is not the review's own value: the review follows it once a page is reached, and moves it when
    /// the current photo changes by other means.
    @State private var pageIdentifier: UUID?

    /// What a page shows of a photo, which the pictures of the page are prepared anew for when it changes.
    private struct PageContent: Equatable {
        let photoIdentifier: UUID
        let drawingIdentifier: UUID?
    }

    /// What the pages one swipe reaches show, and the size their pictures are for: a page that grows, as on iPad
    /// when the window does, prepares its pictures anew.
    private struct PreparedPages: Equatable {
        let contents: [PageContent]
        let maximumPixelSize: Int
    }

    init(
        review: PhotoReviewModel,
        photoSet: PhotoSetModel,
        markup: EmbeddedPhotoMarkupModel,
        layout: CameraScreenLayout
    ) {
        self.review = review
        self.photoSet = photoSet
        self.markup = markup
        self.layout = layout
        _pageIdentifier = State(initialValue: review.currentPhotoIdentifier)
    }

    var body: some View {
        let images = review.images
        let photo = layout.reviewedPhoto
        let pager = layout.reviewPager
        let drawnPhotoIdentifier = markup.session?.photoIdentifier
        let maximumPixelSize = screenPixelSize(of: photo.size)
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pagesInScreenOrder, id: \.element.id) { index, photoOfPage in
                    page(of: photoOfPage, at: PhotoPosition(number: index + 1, count: photoSet.photos.count))
                        .frame(width: photo.width, height: photo.height)
                        .frame(width: pager.width, alignment: .leading)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIdentifier)
        .scrollIndicators(.hidden)
        .scrollDisabled(drawnPhotoIdentifier != nil)
        .frame(width: pager.width, height: pager.height)
        .frame(width: photo.width, height: photo.height, alignment: .leading)
        .clipped()
        .placed(in: photo)
        .task(id: PreparedPages(contents: nearbyContents, maximumPixelSize: maximumPixelSize)) {
            await images.prepare(review.nearbyPhotos, maximumPixelSize: maximumPixelSize)
        }
        .task(id: zoomedPhotoIdentifier) {
            await images.sharpen(photoSet.photos.first { $0.id == zoomedPhotoIdentifier })
        }
        .onChange(of: pageIdentifier) {
            if let pageIdentifier {
                review.show(pageIdentifier)
            }
        }
        .onChange(of: review.currentPhotoIdentifier) { _, currentPhotoIdentifier in
            zoomedPhotoIdentifier = nil
            if pageIdentifier != currentPhotoIdentifier {
                pageIdentifier = currentPhotoIdentifier
            }
        }
        .onChange(of: drawnPhotoIdentifier) {
            // The page of a photo that is drawn on goes back to its fitted size without reporting it.
            if drawnPhotoIdentifier != nil {
                zoomedPhotoIdentifier = nil
            }
        }
    }

    /// The photos of the set with their indices, in the order of the pages from the left: the order of the set, or
    /// the other way in a right-to-left language.
    private var pagesInScreenOrder: [EnumeratedSequence<[FlowPhoto]>.Element] {
        let pages = Array(photoSet.photos.enumerated())
        return localization.isRightToLeft ? pages.reversed() : pages
    }

    /// What the pages one swipe reaches show. The drawing of the photo that is drawn on is left out: the drawing
    /// mode renders its picture itself before it closes.
    private var nearbyContents: [PageContent] {
        let drawnPhotoIdentifier = markup.session?.photoIdentifier
        return review.nearbyPhotos.map { photo in
            PageContent(
                photoIdentifier: photo.id,
                drawingIdentifier: photo.id == drawnPhotoIdentifier ? nil : photo.drawing?.identifier
            )
        }
    }

    private func page(of photo: FlowPhoto, at position: PhotoPosition) -> some View {
        let images = review.images
        let isCurrent = photo.id == review.currentPhotoIdentifier
        let drawnPhotoIdentifier = markup.session?.photoIdentifier
        return ZoomablePhotoPage(
            image: images.image(of: photo),
            drawingImage: photo.id == drawnPhotoIdentifier ? nil : images.drawingImage(of: photo),
            isCurrent: isCurrent,
            isZoomable: drawnPhotoIdentifier == nil
        ) { isZoomed in
            if isZoomed {
                zoomedPhotoIdentifier = photo.id
            } else if zoomedPhotoIdentifier == photo.id {
                zoomedPhotoIdentifier = nil
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier(FlowIdentifier.reviewedPhoto)
        .accessibilityLabel(ReviewText(localization).photo)
        .accessibilityValue(ReviewText(localization).counter(position))
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(!isCurrent)
    }

    /// The long side of a photo that fills the page, in pixels of the screen.
    private func screenPixelSize(of pageSize: CGSize) -> Int {
        Int((max(pageSize.width, pageSize.height) * displayScale).rounded(.up))
    }
}
#endif
