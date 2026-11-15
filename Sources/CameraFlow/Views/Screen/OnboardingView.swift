//
//  OnboardingView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// One step of the introduction: the symbol, the title and the rows a little above the middle of the screen, and
/// the line about the request with Continue at its bottom. Continue is the only way on, and it always brings the
/// system's request: the user answers in the system's alert. Return on a keyboard presses it. The text follows
/// Dynamic Type, and a page taller than the screen scrolls above the button. At the accessibility text sizes the
/// line about the request scrolls with the page, after the rows, and only the button stays at the bottom.
///
/// VoiceOver starts every step at its title. The look is our own, in the manner of the system's welcome screens.
struct OnboardingView: View {
    let page: OnboardingPage
    /// True while a system request is up: the button waits for its answer.
    let isBusy: Bool
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroDiameter = OnboardingMetrics.heroDiameter
    @ScaledMetric(relativeTo: .largeTitle) private var heroSymbolSize = OnboardingMetrics.heroSymbolSize
    @ScaledMetric(relativeTo: .headline) private var rowGlyphWidth = OnboardingMetrics.rowGlyphWidth
    @ScaledMetric(relativeTo: .headline) private var rowGlyphSize = OnboardingMetrics.rowGlyphSize
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        let style = OnboardingMetrics.self
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, style.horizontalPadding)
                    .padding(.vertical, style.verticalPadding)
                    .frame(maxWidth: style.contentMaximumWidth)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
                .padding(.horizontal, style.horizontalPadding)
                .padding(.top, style.actionsTopPadding)
                .padding(.bottom, style.actionsBottomPadding)
                .frame(maxWidth: style.contentMaximumWidth)
                .frame(maxWidth: .infinity)
                .background(CameraPalette.background)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(CameraIdentifier.onboarding)
        .onAppear {
            isTitleFocused = true
        }
    }

    /// Whether the line about the request stays above the button: at the accessibility text sizes it would leave the
    /// page too little room on a small phone, so it scrolls with the page.
    private var isFootnotePinned: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    private var content: some View {
        let style = OnboardingMetrics.self
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            hero
            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundStyle(CameraPalette.label)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, style.heroToTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(CameraIdentifier.onboardingTitle)
                .accessibilityFocused($isTitleFocused)
            VStack(alignment: .leading, spacing: style.rowSpacing) {
                ForEach(page.rows) { row in
                    self.row(row)
                }
            }
            .padding(.top, style.titleToRows)
            if !isFootnotePinned {
                footnote
                    .padding(.top, style.rowsToFootnote)
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
    }

    private var hero: some View {
        Image(systemName: page.symbol.systemName)
            .font(.system(size: heroSymbolSize, weight: .medium))
            .foregroundStyle(CameraPalette.accent)
            .frame(width: heroDiameter, height: heroDiameter)
            .background(CameraPalette.glassFill, in: Circle())
            .overlay {
                Circle().strokeBorder(CameraPalette.selectedSegmentRim, lineWidth: OnboardingMetrics.heroRimWidth)
            }
            .accessibilityHidden(true)
    }

    private func row(_ row: OnboardingPage.Row) -> some View {
        let style = OnboardingMetrics.self
        return HStack(alignment: .center, spacing: style.rowGlyphToText) {
            Image(systemName: row.symbol.systemName)
                .font(.system(size: rowGlyphSize))
                .foregroundStyle(CameraPalette.accent)
                .frame(width: rowGlyphWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: style.rowTitleToDetail) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(CameraPalette.label)
                Text(row.detail)
                    .font(.subheadline)
                    .foregroundStyle(CameraPalette.label.opacity(style.detailOpacity))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var footnote: some View {
        Text(page.footnote)
            .font(.footnote)
            .foregroundStyle(CameraPalette.label.opacity(OnboardingMetrics.footnoteOpacity))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        let style = OnboardingMetrics.self
        return VStack(spacing: 0) {
            if isFootnotePinned {
                footnote
                    .padding(.bottom, style.footnoteToButton)
            }
            Button(page.continueTitle, action: onContinue)
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(CameraIdentifier.onboardingContinue)
        }
        .disabled(isBusy)
        .opacity(isBusy ? style.busyOpacity : 1)
    }
}

/// The capsule in the camera's accent, as wide as the column.
private struct OnboardingPrimaryButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        let style = OnboardingMetrics.self
        configuration.label
            .font(.headline)
            .foregroundStyle(CameraPalette.onAccent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, style.horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: style.buttonMinimumHeight)
            .background(CameraPalette.accent, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? style.pressedOpacity : 1)
    }
}
#endif
