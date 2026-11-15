//
//  OnboardingLayer.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

/// The introduction over the whole flow for as long as it has a step. A step slides away as the next one comes, and
/// the last one fades into the camera. People who reduce motion get a cross-fade.
struct OnboardingLayer: View {
    @Environment(\.flowLocalization) private var localization
    let onboarding: OnboardingModel
    /// Whether the flow offers the picker of the photo library.
    let offersPhotoLibrary: Bool

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        ZStack {
            if let step = onboarding.step {
                ZStack {
                    CameraPalette.background
                        .ignoresSafeArea()
                    let page = OnboardingText(localization).page(for: step, offersPhotoLibrary: offersPhotoLibrary)
                    OnboardingView(page: page, isBusy: onboarding.isAsking) {
                        Task { await onboarding.proceed() }
                    }
                    .id(page)
                    .transition(stepTransition)
                }
                .transition(.opacity)
            }
        }
        .animation(stepAnimation, value: onboarding.step)
    }

    private var stepAnimation: Animation {
        reducesMotion ? OnboardingMotion.stepChangeReduced : OnboardingMotion.stepChange
    }

    private var stepTransition: AnyTransition {
        guard !reducesMotion else { return .opacity }
        let slide = OnboardingMetrics.stepSlide
        return .asymmetric(
            insertion: .offset(x: slide).combined(with: .opacity),
            removal: .offset(x: -slide).combined(with: .opacity)
        )
    }
}
#endif
