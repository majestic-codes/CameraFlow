//
//  ExampleFlowScreen.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import os
import CameraFlow
import SwiftUI
import UniformTypeIdentifiers

/// The camera flow of the example as its own screen, a `CameraFlowView` with the example's configuration.
///
/// It takes over the files of a finished set: the originals and the Live Photo movies move into
/// `Documents/Captures`, a copy with a drawing goes to `Documents/Edited`, and the log gets one line per photo
/// and one more per file, with what the file contains. The example keeps the original beside the copy with the
/// drawing to compare what the two files contain; an app that only needs what the user finished keeps
/// `resultFileURL` and deletes the other files. Every `CameraFlowPreferences` the flow reports is logged, kept in
/// `UserDefaults` and passed to the next flow.
struct ExampleFlowScreen: View {
    let options: CameraFlowLaunchOptions
    /// Receives what the example kept of a finished set.
    let onFinish: (CameraFlowOutcomeLog.Outcome) -> Void
    let onCancel: () -> Void

    var body: some View {
        CameraFlowView(
            configuration: CameraFlowPreferencesStore.configuration(for: options),
            onPreferencesChange: CameraFlowPreferencesStore.store,
            onFinish: { photos in onFinish(CameraFlowOutcomeLog.keep(photos)) },
            onCancel: onCancel
        )
    }
}

/// The user's choices in the flow as the flow reports them, logged and kept across launches as JSON in
/// `UserDefaults`: what an app does that keeps the user's settings itself. The flow remembers them as well, unless
/// the launch options switch its memory off.
enum CameraFlowPreferencesStore {
    private static let key = "cameraFlow.preferences"
    private static let logger = Logger(subsystem: "CameraFlowExample", category: "CameraFlow")

    /// The configuration of the launch options with the stored preferences applied, unless they are switched off.
    static func configuration(for options: CameraFlowLaunchOptions) -> CameraFlowConfiguration {
        var configuration = options.configuration
        if options.appliesStoredPreferences, let stored = load() {
            configuration.preferences = stored
        }
        return configuration
    }

    static func load() -> CameraFlowPreferences? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(CameraFlowPreferences.self, from: data)
        } catch {
            logger.error("Cannot read the stored preferences: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    static func store(_ preferences: CameraFlowPreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: key)
            let json = String(bytes: data, encoding: .utf8) ?? "not UTF-8"
            logger.notice("camera flow preferences \(json, privacy: .public)")
        } catch {
            logger.error("Cannot store the preferences: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Takes over the photos of a finished set and logs what their files contain.
enum CameraFlowOutcomeLog {
    /// What the example made of a finished set.
    struct Outcome {
        /// The photos the example took over, in the order of the set.
        let kept: [ExamplePhoto]
        /// How many photos of the set the example could not take over. Their files are gone.
        let lostCount: Int
    }

    private static let logger = Logger(subsystem: "CameraFlowExample", category: "CameraFlow")

    /// Takes over the files of every photo of a set and logs one line about each and one about each of its files. A
    /// photo the example cannot take over is counted as lost, and none of its files is left behind.
    static func keep(_ photos: [CameraFlowPhoto]) -> Outcome {
        var kept: [ExamplePhoto] = []
        var lostCount = 0
        for photo in photos {
            do {
                let example = try ExamplePhoto(takingOver: photo)
                kept.append(example)
                log(photo, keptAs: example)
            } catch {
                lostCount += 1
                let name = photo.original.url.lastPathComponent
                let reason = String(describing: error)
                logger.error("Cannot keep the photo \(name, privacy: .public): \(reason, privacy: .public)")
            }
        }
        return Outcome(kept: kept, lostCount: lostCount)
    }

    private static func log(_ photo: CameraFlowPhoto, keptAs example: ExamplePhoto) {
        let report = line(for: photo, kept: example)
        logger.notice("\(report, privacy: .public)")
        logFacts(of: example.fileURL, as: "file")
        if let editedFileURL = example.editedFileURL {
            logFacts(of: editedFileURL, as: "copy")
        }
    }

    /// Logs what a kept file contains. The facts are for the log only, so a file they cannot be read from stays kept.
    private static func logFacts(of fileURL: URL, as kind: String) {
        do {
            let facts = try PhotoFileFacts(fileURL: fileURL)
            logger.notice("camera flow \(kind, privacy: .public) \(facts.line, privacy: .public)")
        } catch {
            let name = fileURL.lastPathComponent
            let reason = String(describing: error)
            logger.error("Cannot read the facts of \(name, privacy: .public): \(reason, privacy: .public)")
        }
    }

    private static func line(for photo: CameraFlowPhoto, kept: ExamplePhoto) -> String {
        [
            "camera flow photo \(kept.fileURL.lastPathComponent)",
            "source \(photo.source)",
            "type \(photo.original.contentType.identifier)",
            "live \(kept.livePhotoMovieURL != nil)",
            "framed \(photo.framedRegion.map { "\($0)" } ?? "all")",
            "saved \(photo.photoLibrarySave.map { "\($0)" } ?? "not saved")",
            "drawing \(kept.editedFileURL?.lastPathComponent ?? "none")",
            "result \(kept.resultFileURL.lastPathComponent)"
        ].joined(separator: " | ")
    }
}

extension ExamplePhoto {
    /// Takes over a photo of a finished set: the original and its Live Photo movie move into `Documents/Captures`,
    /// and the copy with the drawing, if any, into `Documents/Edited`. The thumbnail is the flow's, of the result.
    ///
    /// A photo is taken over whole or not at all: when a file cannot be moved, every file of the photo is removed,
    /// the ones already moved and the ones still in the flow's folder, which the app owns once the flow handed them
    /// over, and the error is thrown.
    init(takingOver photo: CameraFlowPhoto) throws {
        var moved: [URL] = []
        do {
            let directory = try ExampleFiles.capturesDirectory()
            let original = try ExampleFiles.move(photo.original.url, into: directory)
            moved.append(original)
            var movie: URL?
            if let flowMovie = photo.livePhotoMovieURL {
                let keptMovie = try ExampleFiles.move(flowMovie, into: directory)
                moved.append(keptMovie)
                movie = keptMovie
            }
            var edited: URL?
            if let markedUp = photo.markedUp {
                let keptCopy = try ExampleFiles.moveEditedCopy(at: markedUp.url, of: original)
                moved.append(keptCopy)
                edited = keptCopy
            }
            id = photo.id
            fileURL = original
            livePhotoMovieURL = movie
            editedFileURL = edited
            thumbnail = photo.thumbnail
        } catch {
            let handedOver = [photo.original.url, photo.livePhotoMovieURL, photo.markedUp?.url].compactMap(\.self)
            ExampleFiles.remove(moved + handedOver)
            throw error
        }
    }
}

extension View {

    /// Presents the camera flow of the example full screen while the binding is true. A finished set closes it and
    /// hands back what the example kept of it.
    func exampleCameraFlowCover(
        isPresented: Binding<Bool>,
        options: CameraFlowLaunchOptions,
        onFinish: @escaping (CameraFlowOutcomeLog.Outcome) -> Void
    ) -> some View {
        cameraFlowCover(isPresented: isPresented) {
            ExampleFlowScreen(
                options: options,
                onFinish: { outcome in
                    isPresented.wrappedValue = false
                    onFinish(outcome)
                },
                onCancel: { isPresented.wrappedValue = false }
            )
        }
    }
}
