//
//  OnboardingMotion.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

#if os(iOS)
import SwiftUI

enum OnboardingMotion {
    /// One step giving way to the next, and the last one to the camera.
    static let stepChange = Animation.spring(response: 0.45, dampingFraction: 0.9)
    /// The same for people who reduce motion: a plain cross-fade.
    static let stepChangeReduced = Animation.easeInOut(duration: 0.25)
}
#endif
