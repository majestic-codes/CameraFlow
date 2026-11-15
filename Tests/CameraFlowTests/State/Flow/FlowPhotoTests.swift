//
//  FlowPhotoTests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 06.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import Foundation
import Testing
@testable import CameraFlow

@Suite("Flow photo", .temporaryDirectory)
struct FlowPhotoTests {
    let files = CaptureTestSupport.makeFileStore()

    @Test("A capture becomes a photo of the camera with its file and its movie")
    func fromCapture() throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withMovie: true)
        let photo = FlowPhoto(capture: capture)
        #expect(photo.id == capture.id)
        #expect(photo.source == .camera)
        #expect(photo.fileURL == capture.fileURL)
        #expect(photo.contentType == .jpeg)
        #expect(photo.livePhotoMovieURL == capture.livePhotoMovieURL)
        #expect(photo.thumbnail === capture.thumbnail)
        let movieURL = try #require(capture.livePhotoMovieURL)
        #expect(photo.fileURLs == [capture.fileURL, movieURL])
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A library photo becomes a still photo of the photo library")
    func fromLibraryPhoto() throws {
        let libraryPhoto = LibraryPhoto(
            id: UUID(),
            fileURL: files.directory.appendingPathComponent("photo.heic"),
            contentType: .heic,
            thumbnail: try FlowTestSupport.makeImage(width: 3, height: 4)
        )
        let photo = FlowPhoto(libraryPhoto: libraryPhoto)
        #expect(photo.id == libraryPhoto.id)
        #expect(photo.source == .photoLibrary)
        #expect(photo.fileURL == libraryPhoto.fileURL)
        #expect(photo.contentType == .heic)
        #expect(photo.livePhotoMovieURL == nil)
        #expect(photo.fileURLs == [libraryPhoto.fileURL])
    }

    @Test("The app receives a photo as the set holds it, with no copy when nothing was drawn on it")
    func handedOver() throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withMovie: true)
        let photo = FlowPhoto(capture: capture)
        let handedOver = CameraFlowPhoto(photo, markedUpCopy: nil, photoLibrarySave: nil)
        #expect(handedOver.id == photo.id)
        #expect(handedOver.source == .camera)
        #expect(handedOver.original.url == photo.fileURL)
        #expect(handedOver.original.contentType == photo.contentType)
        #expect(handedOver.livePhotoMovieURL == photo.livePhotoMovieURL)
        #expect(handedOver.markedUp?.url == nil)
        #expect(handedOver.markedUp?.contentType == nil)
        #expect(handedOver.result.url == photo.fileURL)
        #expect(handedOver.result.contentType == photo.contentType)
        #expect(handedOver.thumbnail === photo.thumbnail)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("The app receives a photo with a drawing with the copy that was written of it")
    func handedOverWithCopy() throws {
        let capture = try FlowTestSupport.makeCapture(in: files)
        var photo = FlowPhoto(capture: capture)
        photo.drawing = try FlowTestSupport.makeDrawing()
        let copyURL = files.directory.appendingPathComponent("copy.heic")
        let copyThumbnail = try FlowTestSupport.makeImage(width: 8, height: 6)
        let copy = MarkedUpCopy(fileURL: copyURL, contentType: .heic, thumbnail: copyThumbnail)
        let handedOver = CameraFlowPhoto(photo, markedUpCopy: copy, photoLibrarySave: nil)
        #expect(handedOver.original.url == photo.fileURL)
        #expect(handedOver.original.contentType == .jpeg)
        #expect(handedOver.markedUp?.url == copyURL)
        #expect(handedOver.markedUp?.contentType == .heic)
        #expect(handedOver.result.url == copyURL)
        #expect(handedOver.result.contentType == .heic)
        #expect(handedOver.thumbnail === copyThumbnail)
        try CaptureTestSupport.discardFiles(of: capture)
    }

    @Test("A photo with the circle comes with the copy's type, and a drawing over it with the drawn copy's")
    func handedOverDualCameraCopy() throws {
        let capture = try FlowTestSupport.makeCapture(in: files, withDualCameraCopy: true)
        var photo = FlowPhoto(capture: capture)
        #expect(photo.dualCameraCopy?.contentType == .jpeg)
        let circle = CameraFlowPhoto(photo, markedUpCopy: nil, photoLibrarySave: nil)
        #expect(circle.markedUp?.url == capture.dualCameraCopy?.url)
        #expect(circle.markedUp?.contentType == .jpeg)
        photo.drawing = try FlowTestSupport.makeDrawing()
        let copyURL = files.directory.appendingPathComponent("copy.heic")
        let thumbnail = try FlowTestSupport.makeImage(width: 8, height: 6)
        let copy = MarkedUpCopy(fileURL: copyURL, contentType: .heic, thumbnail: thumbnail)
        let drawn = CameraFlowPhoto(photo, markedUpCopy: copy, photoLibrarySave: nil)
        #expect(drawn.markedUp?.url == copyURL)
        #expect(drawn.markedUp?.contentType == .heic)
        try CaptureTestSupport.discardFiles(of: capture)
    }
}
