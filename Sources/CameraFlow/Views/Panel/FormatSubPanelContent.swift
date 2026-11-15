//
//  FormatSubPanelContent.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// Options of the Format sub-panel: HEIF or RAW, the quality where the user picks it, and the footnote.
///
/// Only the formats the running camera and the flow offer now are shown, and the one in effect is selected. A
/// format stands in its row alone too. A row the app fixed, or that the output leaves no option for, is left out
/// with its label. The rows share their columns, which stand where `FormatPanelColumns` puts them for the words of
/// the language and the width of the card.
///
/// The quality row comes with the approximate size of one photo as the footnote, which follows the quality, the
/// aspect ratio and the format. A format the chosen quality rules out (RAW) stays in its row dimmed and inert, so
/// the rows keep their places.
struct FormatSubPanelContent: View {
    @Environment(\.flowLocalization) private var localization
    @Environment(\.accessibilityShowButtonShapes) private var showsButtonShapes
    @Environment(\.colorSchemeContrast) private var contrast
    let settings: PhotoSettingsModel
    /// The width of the card the options are laid out in.
    let cardWidth: CGFloat

    private typealias Metrics = CameraMetrics.FormatPanel

    var body: some View {
        let formats = settings.offeredPhotoFormats
        let qualities = settings.offeredPhotoQualities
        let optionWidths = measuredOptionWidths(formats: formats, qualities: qualities)
        let labels = [
            formats.isEmpty ? nil : CameraSettingText(localization).title(of: .format),
            qualities.isEmpty ? nil : CameraSettingText(localization).qualityTitle
        ]
        let tracking = LetterTracking(localization)
        let labelWidths = labels.compactMap(\.self).map { CameraTypography.formatRowLabelWidth($0, tracking: tracking) }
        let labelWidth = labelWidths.max() ?? 0
        let columns = FormatPanelColumns(optionWidths: optionWidths, cardWidth: cardWidth, labelWidth: labelWidth)
        SubPanelOptionCanvas {
            if !formats.isEmpty {
                let title = CameraSettingText(localization).title(of: .format)
                rowLabel(title, leading: columns.labelLeading, baseline: Metrics.formatBaseline)
            }
            if !qualities.isEmpty {
                let title = CameraSettingText(localization).qualityTitle
                rowLabel(title, leading: columns.labelLeading, baseline: Metrics.qualityBaseline)
                photoSize
                    .subPanelCentered(baseline: Metrics.photoSizeBaseline)
            }
            formatOptions(formats, columns: columns)
            qualityOptions(qualities, columns: columns)
        }
    }

    /// The width of the widest option of each column, its selection bullet included.
    private func measuredOptionWidths(
        formats: [CameraFlowPhotoFormat],
        qualities: [CameraFlowQuality]
    ) -> [CGFloat] {
        let rows = [
            formats.map { CameraTypography.formatOptionWidth($0.rawValue) },
            qualities.map { CameraTypography.formatOptionWidth(CameraSettingText(localization).quality($0)) }
        ]
        let columnCount = rows.map(\.count).max() ?? 0
        return (0..<columnCount).map { column in
            let widest = rows.compactMap { $0.indices.contains(column) ? $0[column] : nil }.max() ?? 0
            return FormatPanelColumns.optionWidth(textWidth: widest)
        }
    }

    private func formatOptions(_ formats: [CameraFlowPhotoFormat], columns: FormatPanelColumns) -> some View {
        ForEach(Array(formats.enumerated()), id: \.element) { column, format in
            let isAvailable = settings.availablePhotoFormats.contains(format)
            valueButton(
                name: format.rawValue.lowercased(),
                text: OptionText(written: format.rawValue, spoken: format.rawValue),
                isSelected: isAvailable && settings.effectivePhotoFormat == format,
                isEnabled: isAvailable
            ) {
                settings.select(photoFormat: format)
            } value: {
                Text(format.rawValue)
            }
            .subPanelPlaced(leading: columns.leadings[column], baseline: Metrics.formatBaseline)
        }
    }

    private func qualityOptions(_ qualities: [CameraFlowQuality], columns: FormatPanelColumns) -> some View {
        ForEach(Array(qualities.enumerated()), id: \.element) { column, quality in
            let text = OptionText(
                written: CameraSettingText(localization).quality(quality),
                spoken: CameraSettingSpeech(localization).quality(quality)
            )
            valueButton(name: quality.rawValue, text: text, isSelected: settings.photoQuality == quality) {
                settings.select(photoQuality: quality)
            } value: {
                Text(text.written)
            }
            .subPanelPlaced(leading: columns.leadings[column], baseline: Metrics.qualityBaseline)
        }
    }

    /// The approximate size of one photo, empty until the camera has started.
    @ViewBuilder private var photoSize: some View {
        if let estimate = PhotoSizeEstimate(settings: settings) {
            footnote(CameraSettingText(localization).photoSizeFootnote(byteCount: estimate.byteCount))
                .accessibilityIdentifier(CameraIdentifier.subPanelPhotoSize)
        }
    }

    private func footnote(_ text: String) -> some View {
        let opacity = contrast == .increased
            ? CameraPalette.formatFootnoteIncreasedOpacity
            : CameraPalette.formatFootnoteOpacity
        return Text(text)
            .font(CameraTypography.formatFootnote)
            .foregroundStyle(CameraPalette.label.opacity(opacity))
    }

    private func rowLabel(_ text: String, leading: CGFloat, baseline: CGFloat) -> some View {
        Text(text)
            .font(CameraTypography.formatRowLabel)
            .tracking(CameraTypography.formatRowLabelTracking(LetterTracking(localization)))
            .foregroundStyle(CameraPalette.label)
            .accessibilityAddTraits(.isHeader)
            .subPanelPlaced(leading: leading, baseline: baseline - Metrics.rowLabelRise)
    }

    /// What an option writes, and what accessibility reads for it.
    private struct OptionText {
        let written: String
        let spoken: String

        /// What Voice Control answers to: the written text where it differs from the spoken one, and the spoken one.
        var inputLabels: [String] {
            written == spoken ? [spoken] : [written, spoken]
        }
    }

    private func valueButton(
        name: String,
        text: OptionText,
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder value: () -> some View
    ) -> some View {
        let content = value()
        let bulletRise = Metrics.bulletRise
        return Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.bulletGap) {
                Circle()
                    .fill(CameraPalette.accent)
                    .frame(width: Metrics.bulletSize, height: Metrics.bulletSize)
                    .opacity(isSelected ? 1 : 0)
                    .alignmentGuide(.firstTextBaseline) { dimensions in dimensions.height + bulletRise }
                content
                    .font(CameraTypography.formatOption)
                    .foregroundStyle(isSelected ? CameraPalette.accent : CameraPalette.label)
                    .underline(showsButtonShapes)
            }
            .padding(.trailing, Metrics.optionTrailingPadding)
            .frame(minHeight: CameraMetrics.SubPanel.optionHitHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(TouchDownButtonStyle(onTouchDown: settings.optionTouched))
        .opacity(isEnabled ? 1 : CameraPalette.unavailableOpacity)
        .disabled(!isEnabled)
        .accessibilityIdentifier(CameraIdentifier.subPanelOption(name))
        .accessibilityLabel(text.spoken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityInputLabels(text.inputLabels)
        .showsLargeContent(text.spoken)
    }
}
#endif
