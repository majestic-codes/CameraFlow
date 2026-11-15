//
//  CapturedPhotoFlight.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// A small copy of a photo the camera has just added to the set, flying from the viewfinder into the review
/// segment: it shows where the photo went, now that the screen has no thumbnail of the last one.
///
/// A photo from the library does not fly, and nothing flies while the control panel covers the bottom bar. For
/// people who reduce motion nothing flies either: the photo lands at once, so the count of the set still shows it.
struct CapturedPhotoFlight: View {
    let photoSet: PhotoSetModel
    let panel: ControlPanelModel
    let layout: CameraScreenLayout
    /// The centre of the review segment, where the copy lands.
    let landingPoint: CGPoint
    let onLanded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reducesMotion
    @State private var flyingPhoto: FlowPhoto?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let flyingPhoto {
                FlyingPhoto(photo: flyingPhoto, start: layout.captureFlightStart, landingPoint: landingPoint) {
                    land(flyingPhoto)
                }
                .id(flyingPhoto.id)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: photoSet.count) { previousCount, count in
            guard count > previousCount, !panel.isOpen else { return }
            guard let photo = photoSet.photos.last, photo.source == .camera else { return }
            guard !reducesMotion else {
                onLanded()
                return
            }
            flyingPhoto = photo
        }
    }

    private func land(_ photo: FlowPhoto) {
        onLanded()
        if flyingPhoto?.id == photo.id {
            flyingPhoto = nil
        }
    }
}

/// One copy on its way: it shrinks and fades as it travels.
private struct FlyingPhoto: View {
    let photo: FlowPhoto
    let start: CGRect
    let landingPoint: CGPoint
    let onLanded: () -> Void

    @State private var isLanding = false

    var body: some View {
        let metrics = FlowMetrics.CaptureFlight.self
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        let landing = start.offsetBy(dx: landingPoint.x - start.midX, dy: landingPoint.y - start.midY)
        Image(decorative: photo.thumbnail, scale: 1)
            .resizable()
            .scaledToFit()
            .clipShape(shape)
            .overlay(shape.strokeBorder(CameraPalette.photoRim))
            .rotatesWithDevice()
            .scaleEffect(isLanding ? metrics.landingScale : 1)
            .opacity(isLanding ? metrics.landingOpacity : 1)
            .placed(in: isLanding ? landing : start)
            .onAppear {
                withAnimation(FlowMotion.captureFlight) {
                    isLanding = true
                } completion: {
                    onLanded()
                }
            }
    }
}
#endif
