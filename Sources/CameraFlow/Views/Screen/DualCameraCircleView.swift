//
//  DualCameraCircleView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 09.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The second camera in a circle in the top trailing corner of the viewfinder, the front one mirrored like a selfie
/// preview, with a light rim and a soft shadow. It shows while the circle is on, keeps its place and size when the
/// cameras swap, lets every touch through to the viewfinder, and tells the model where it is laid out, for the
/// capture to put the circle's frame there. It grows in from its corner and shrinks back into it, or fades in and out
/// in its place for people who reduce motion.
///
/// Its content needs no turn of its own: each camera's preview is turned by that camera's rotation coordinator, and
/// both cameras turn with the phone, so the circle shows its picture upright in every hold, as the viewfinder does.
struct DualCameraCircleView: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dualCamera: DualCameraModel
    let layout: CameraScreenLayout
    let makePreview: () -> any CameraPreview

    var body: some View {
        let metrics = FlowMetrics.DualCameraCircle.self
        let frame = layout.dualCameraCircle
        let circleLabel = CameraControlText(localization).dualCameraCircle(showing: dualCamera.circlePosition)
        ZStack {
            if dualCamera.isOn {
                CameraLayerHost(makePreview: makePreview, covers: dualCamera.pictureCovers)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(CameraPalette.dualCameraRim, lineWidth: metrics.rimWidth))
                    .background(
                        Circle()
                            .fill(CameraPalette.background)
                            .shadow(color: CameraPalette.dualCameraShadow, radius: metrics.shadowRadius)
                    )
                    .transition(circleTransition)
                    .accessibilityElement()
                    .accessibilityIdentifier(CameraIdentifier.dualCameraCircle)
                    .accessibilityLabel(circleLabel)
                    .accessibilityAddTraits(.isImage)
            }
        }
        .animation(FlowMotion.dualCameraCircle, value: dualCamera.isOn)
        .allowsHitTesting(false)
        .placed(in: frame)
        .onChange(of: layout.dualCameraCirclePlacement, initial: true) { _, placement in
            guard let placement else { return }
            dualCamera.circleLaidOut(placement)
        }
    }

    private var circleTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .scale(scale: FlowMotion.dualCameraCircleHiddenScale, anchor: .topTrailing).combined(with: .opacity)
    }
}
#endif
