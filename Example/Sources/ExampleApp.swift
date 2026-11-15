//
//  ExampleApp.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 05.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import SwiftUI

@main
struct CameraFlowExampleApp: App {
    /// The options of the launch, read once the files of the last launch are gone and, when the options ask for it,
    /// the stored state as well.
    private let launchOptions: Result<CameraFlowLaunchOptions, any Error>

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        launchOptions = Result {
            let options = try CameraFlowLaunchOptions(arguments: arguments)
            try ExampleFiles.removeAll()
            if options.resetsState {
                try ExampleDefaults.removeAll()
            }
            return options
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launchOptions {
            case let .success(options):
                ContentView(launchOptions: options)
            case let .failure(error):
                Text("The example cannot start: \(String(describing: error))")
                    .padding()
                    .accessibilityIdentifier("example.launchError")
            }
        }
    }
}
