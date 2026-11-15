//
//  LoggedReasonTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 14.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

/// What a log shows of a failure in every build, and what it keeps for where it shows private data: the folders and
/// the files of the device, and the values of a photo.
@Suite("A failure as a log shows it", .temporaryDirectory)
struct LoggedReasonTests {

    /// The error of removing a file that is not there, in a folder of the test.
    private func removalError() throws -> (error: CocoaError, folder: URL) {
        let folder = TestDirectory.current.appendingPathComponent("Captures", isDirectory: true)
        let missing = folder.appendingPathComponent("1A2B3C4D.heic")
        let thrown = #expect(throws: CocoaError.self) {
            try FileManager.default.removeItem(at: missing)
        }
        return (try #require(thrown), folder)
    }

    @Test("A failure of the file system shows its localized description, its folders only as private data")
    func fileSystemError() throws {
        let removal = try removalError()
        let folders = removal.folder.path
        try #require(String(describing: removal.error).contains(folders), "The error names no folder")
        let reason = LoggedReason(removal.error)
        #expect(reason.summary == removal.error.localizedDescription)
        #expect(reason.summary.contains(folders) == false)
        #expect(reason.summary.contains("1A2B3C4D.heic"))
        #expect(reason.details.contains(folders))
    }

    @Test(
        "A failure of a photo file of the package shows whole, with nothing kept back",
        arguments: [
            CameraServiceError.cannotStore("Cannot write the photo file: “1A2B3C4D.heic” is locked") as any Error,
            CameraServiceError.noImageData,
            PhotoOutputFailure.cannotEncode("ImageIO cannot write public.heic"),
            PhotoOutputFailure.unreadablePhoto
        ]
    )
    func packageError(error: any Error) {
        let reason = LoggedReason(error)
        #expect(reason == LoggedReason(String(describing: error)))
        #expect(reason.details.isEmpty)
        #expect(reason.description == String(describing: error))
    }

    @Test("A failure of a drawing shows whole, and names its photo by its file without the folders")
    func drawingFailure() {
        let folder = TestDirectory.current.appendingPathComponent("Captures", isDirectory: true)
        let photo = folder.appendingPathComponent("1A2B3C4D.heic")
        let reason = LoggedReason(MarkupFailure.unreadablePhoto(photo))
        #expect(reason.summary == "The photo 1A2B3C4D.heic cannot be read")
        #expect(reason.summary.contains(folder.path) == false)
        #expect(reason.details.isEmpty)
    }

    @Test(
        "Every failure of a drawing says what failed in words",
        arguments: [
            (MarkupFailure.engineUnavailable(.paperKit), "The drawing engine paperKit does not exist on this system"),
            (.undecodableDrawing(.pencilKit, "torn"), "The drawing engine pencilKit cannot read the drawing: torn"),
            (.unencodableDrawing(.paperKit, "no data"), "The drawing engine paperKit cannot keep the drawing: no data"),
            (.emptyCanvas(CGSize(width: 0, height: 300)), "A drawing needs a canvas with an area, not 0.0 x 300.0"),
            (.cannotCreateBitmap(width: 4, height: 0), "There is no bitmap of 4 x 0 pixels to draw into"),
            (.cannotEncodeCopy("ImageIO cannot write public.heic"), "ImageIO cannot write public.heic"),
            (.cannotStoreCopy("The device refused the file"), "The device refused the file"),
            (.notEnoughStorage, "The device has too little room left for the copy")
        ]
    )
    func drawingFailureWords(failure: MarkupFailure, words: String) {
        #expect(LoggedReason(failure).summary == words)
    }

    @Test("A Live Photo of the library that names its files keeps them for private data")
    func libraryFileNames() {
        let error = PhotoLibraryPickError.unreadableLivePhoto(fileNames: ["IMG_0042.HEIC", "IMG_0042.MOV", "notes.txt"])
        let reason = LoggedReason(error)
        #expect(reason.summary.contains("IMG_0042") == false)
        #expect(reason.details.contains("IMG_0042.HEIC"))
    }

    @Test("A reason shows its details after its summary")
    func description() {
        #expect(LoggedReason("The photo changed").description == "The photo changed")
        let reason = LoggedReason("The written photo changed {Exif}.FNumber", details: "1.78 to 2.8")
        #expect(reason.description == "The written photo changed {Exif}.FNumber (1.78 to 2.8)")
    }
}
