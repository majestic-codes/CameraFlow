//
//  ReviewStrip.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The strip of the set under the photo: a round tile per photo, in the order of the set, and the "+" that opens
/// the photo library in a flow that offers it. A tap on a tile shows its photo. A strip wider than the screen
/// scrolls sideways and keeps the tile of the current photo in its middle. In a right-to-left language the set runs
/// from the right.
struct ReviewStrip: View {
    @Environment(\.flowLocalization) private var localization
    let flow: EmbeddedCameraFlowModel
    let layout: ReviewStripLayout

    var body: some View {
        let review = flow.review
        let currentPhotoIdentifier = review.currentPhotoIdentifier
        ScrollViewReader { scrollViewProxy in
            ScrollView(.horizontal) {
                tiles(currentPhotoIdentifier: currentPhotoIdentifier)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onAppear {
                guard let currentPhotoIdentifier else { return }
                scrollViewProxy.scrollTo(currentPhotoIdentifier, anchor: .center)
            }
            .onChange(of: currentPhotoIdentifier) {
                guard let currentPhotoIdentifier else { return }
                withAnimation(FlowMotion.stripFollow) {
                    scrollViewProxy.scrollTo(currentPhotoIdentifier, anchor: .center)
                }
            }
        }
        .placed(in: layout.frame)
    }

    private func tiles(currentPhotoIdentifier: UUID?) -> some View {
        let photos = flow.photoSet.photos
        return ReviewStripTiles(layout: layout) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                let position = PhotoPosition(number: index + 1, count: photos.count)
                ReviewStripPhotoTile(photo: photo, isCurrent: photo.id == currentPhotoIdentifier) {
                    flow.review.show(photo.id)
                }
                .accessibilityIdentifier(FlowIdentifier.reviewTile(position.number))
                .accessibilityLabel(ReviewText(localization).tile(position))
            }
            if flow.isLibraryPickerEnabled {
                ReviewStripAddTile(action: flow.openLibrary)
                    .disabled(!flow.canOpenLibrary)
                    .accessibilityIdentifier(FlowIdentifier.reviewAdd)
                    .accessibilityLabel(ReviewText(localization).addFromLibrary)
            }
        }
    }
}

/// Places the tiles of the strip one after another at the frames of the layout.
private struct ReviewStripTiles: Layout {
    let layout: ReviewStripLayout

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        CGSize(width: layout.scrolledWidth(tileCount: subviews.count), height: layout.frame.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        for (index, subview) in subviews.enumerated() {
            let tile = layout.tile(at: index, of: subviews.count)
            let origin = CGPoint(x: bounds.minX + tile.minX, y: bounds.minY + tile.minY)
            subview.place(at: origin, proposal: ProposedViewSize(tile.size))
        }
    }
}
#endif
