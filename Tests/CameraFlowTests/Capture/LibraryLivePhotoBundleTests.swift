//
//  LibraryLivePhotoBundleTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// The bundle the photo library lends a Live Photo pick in, copied into the package's directories.
@Suite("The bundle of a Live Photo pick", .temporaryDirectory, .timeLimit(.minutes(1)))
struct LibraryLivePhotoBundleTests {
    private let photo = Data("photo".utf8)
    private let movie = Data("movie".utf8)

    private var root: URL {
        TestDirectory.current.appendingPathComponent("CameraFlow", isDirectory: true)
    }

    /// A bundle directory holding files of the names given, a photo's bytes in images and a movie's in movies.
    private func makeBundle(_ names: [String]) throws -> URL {
        let bundle = TestDirectory.current.appendingPathComponent("IMG_0001.pvt", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        for name in names {
            let bytes = name.uppercased().hasSuffix(".MOV") ? movie : photo
            try bytes.write(to: bundle.appendingPathComponent(name))
        }
        return bundle
    }

    private func copiedFileCount() throws -> Int {
        guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.count { !$0.path.contains("/.runs") && !$0.hasDirectoryPath }
    }

    @Test("The photo and the movie are copied into the package's directories, and the bundle stays as it is")
    func copied() throws {
        let bundle = try makeBundle(["IMG_0001.HEIC", "IMG_0001.MOV"])
        let files = try LibraryLivePhotoBundle.copyFiles(of: bundle, parent: TestDirectory.current)
        #expect(try Data(contentsOf: files.photoURL) == photo)
        #expect(files.photoURL.pathExtension == "HEIC")
        let movieURL = try #require(files.livePhotoMovieURL)
        #expect(try Data(contentsOf: movieURL) == movie)
        #expect(movieURL.pathExtension == "mov")
        for url in files.fileURLs {
            #expect(url.path.hasPrefix(root.path))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: bundle.path).count == 2)
    }

    @Test(
        "A bundle without one photo and one movie is refused, and nothing is copied",
        arguments: [["IMG_0001.HEIC"], ["IMG_0001.MOV"], ["IMG_0001.HEIC", "IMG_E0001.HEIC", "IMG_0001.MOV"], []]
    )
    func refused(names: [String]) throws {
        let bundle = try makeBundle(names)
        #expect(throws: PhotoLibraryPickError.unreadableLivePhoto(fileNames: names.sorted())) {
            try LibraryLivePhotoBundle.copyFiles(of: bundle, parent: TestDirectory.current)
        }
        #expect(try copiedFileCount() == 0)
    }

    @Test("A file that is neither a photo nor a movie is passed over")
    func otherFiles() throws {
        let bundle = try makeBundle(["IMG_0001.HEIC", "IMG_0001.MOV", "Info.plist"])
        let files = try LibraryLivePhotoBundle.copyFiles(of: bundle, parent: TestDirectory.current)
        #expect(try Data(contentsOf: files.photoURL) == photo)
        #expect(files.livePhotoMovieURL != nil)
    }
}
