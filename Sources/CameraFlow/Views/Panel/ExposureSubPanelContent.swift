//
//  ExposureSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The exposure ruler of the Exposure sub-panel: a drag moves the ticks under the yellow centre mark.
///
/// The ticks cover the exposure bias range the running camera accepts.
struct ExposureSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    let settings: PhotoSettingsModel

    @State private var dragStartBias: Double?
    /// Whether a finger drags the ruler. It goes back to false when the drag ends and when the system takes it
    /// away.
    @GestureState private var isDragging = false

    var body: some View {
        SubPanelOptionCanvas {
            SubPanelRulerTicks(bias: settings.exposureBias, range: settings.availableExposureBiasRange)
        }
        .contentShape(Rectangle())
        .gesture(drag)
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging {
                dragStartBias = nil
            }
        }
        .accessibilityElement()
        .accessibilityIdentifier(CameraIdentifier.subPanelOption("ruler"))
        .accessibilityLabel(CameraSettingSpeech(localization).name(of: .exposure))
        .accessibilityValue(CameraSettingSpeech(localization).value(of: .exposure, in: settings))
        .exposureAdjustableAction(settings.stepExposureBias(by:))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, isDragging, _ in
                isDragging = true
            }
            .onChanged { value in
                let start = dragStartBias ?? settings.exposureBias
                dragStartBias = start
                let bias = SubPanelRulerScale.bias(from: start, translation: value.translation.width)
                settings.setExposureBias(bias)
            }
            .onEnded { _ in
                dragStartBias = nil
            }
    }
}
#endif
