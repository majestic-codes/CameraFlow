//
//  ContentView.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import SwiftUI

/// The stand: it opens the camera flow through SwiftUI or through UIKit and lists the photos the example kept in this
/// launch. The files of a launch are removed at the next one.
struct ContentView: View {
    let launchOptions: CameraFlowLaunchOptions
    @State private var isCameraFlowPresented: Bool
    @State private var isUIKitFlowRequested: Bool
    @State private var photos: [ExamplePhoto] = []
    /// How many photos of the last set the example could not take over.
    @State private var lostPhotoCount = 0

    init(launchOptions: CameraFlowLaunchOptions) {
        self.launchOptions = launchOptions
        _isCameraFlowPresented = State(initialValue: launchOptions.opensAtLaunch)
        _isUIKitFlowRequested = State(initialValue: launchOptions.opensThroughUIKit)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button("Open camera flow") {
                    isCameraFlowPresented = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("example.openCameraFlow")
                Button("Open camera flow (UIKit)") {
                    isUIKitFlowRequested = true
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("example.openCameraFlowUIKit")
                Text("^[\(photos.count) photo](inflect: true)")
                    .accessibilityIdentifier("example.photoCount")
                if lostPhotoCount > 0 {
                    Text("^[\(lostPhotoCount) photo](inflect: true) of the last set could not be kept")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("example.lostPhotos")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(photos) { photo in
                        Image(decorative: photo.thumbnail, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                            .accessibilityLabel(photo.resultFileURL.lastPathComponent)
                    }
                }
            }
            .padding()
        }
        .exampleCameraFlowCover(isPresented: $isCameraFlowPresented, options: launchOptions, onFinish: receive)
        .exampleCameraFlowController(isRequested: $isUIKitFlowRequested, options: launchOptions, onFinish: receive)
    }

    /// Adds the photos the example kept of a finished set and counts the ones it lost.
    private func receive(_ outcome: CameraFlowOutcomeLog.Outcome) {
        photos.append(contentsOf: outcome.kept)
        lostPhotoCount = outcome.lostCount
    }
}
