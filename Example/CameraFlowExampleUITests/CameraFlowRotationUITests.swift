//
//  CameraFlowRotationUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The upright elements as the device turns: the shooting mode turns them with the phone, the review and the
/// drawing keep them upright in the interface. The simulated camera follows the orientation of the simulator's
/// device, which the runner turns. A button is compared with a picture of itself taken while the device stood
/// portrait: the same picture means upright, a different one means turned.
@MainActor
final class CameraFlowRotationUITests: XCTestCase, CameraFlowDriving {
    /// The share of pixels two pictures of one upright button may differ in.
    private let sameShare = 0.01
    /// The share of pixels a check mark turned a quarter or a half differs in from another one at the least: the thin
    /// glyph covers a few percent of the button.
    private let turnedShare = 0.025
    /// A black scene, so the glass of the buttons shows the same behind it in every mode.
    private let blackScene = ["-cameraFlowScene", "0,0,0"]

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Turns the device back upright, also after a failed test, so the next test starts in portrait.
    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
        try await super.tearDown()
    }

    /// On iPhone the interface stays portrait and the shooting mode turns its elements. On iPad the interface turns
    /// with the device, so every mode stands upright in it.
    private var interfaceTurnsWithTheDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    func testReviewAndMarkupStandUprightWhileTheShootingModeTurnsWithThePhone() throws {
        let app = launchReview(photoCount: 1, blackScene)
        let accept = element(FlowElement.accept, in: app)
        let trash = element(FlowElement.reviewDelete, in: app)
        let markup = element(FlowElement.reviewMarkup, in: app)
        let uprightTrash = try settledPicture(of: trash)
        let uprightMarkup = try settledPicture(of: markup)
        let uprightReviewAccept = try settledPicture(of: accept)
        tap(markup)
        let undo = element(FlowElement.markupUndo, in: app)
        XCTAssertTrue(waitUntilHittable(undo))
        let uprightUndo = try settledPicture(of: undo)
        tap(element(FlowElement.markupCancel, in: app))
        XCTAssertTrue(waitUntilHittable(trash))
        showShooting(in: app)
        let uprightShootingAccept = try settledPicture(of: accept)

        XCUIDevice.shared.orientation = .landscapeLeft
        let turnedLeftAccept = try settledPicture(of: accept)
        try expectShootingTurned(turnedLeftAccept, from: uprightShootingAccept)

        openReview(in: app)
        let reviewTrash = try settledPicture(of: trash)
        try expectSame(reviewTrash, uprightTrash, "trash in the review")
        let reviewMarkup = try settledPicture(of: markup)
        try expectSame(reviewMarkup, uprightMarkup, "markup in the review")
        let reviewAccept = try settledPicture(of: accept)
        try expectSame(reviewAccept, uprightReviewAccept, "check mark in the review")

        tap(markup)
        XCTAssertTrue(waitUntilHittable(undo))
        let drawingUndo = try settledPicture(of: undo)
        try expectSame(drawingUndo, uprightUndo, "undo in the drawing")
        XCUIDevice.shared.orientation = .landscapeRight
        let turnedUndo = try settledPicture(of: undo)
        try expectSame(turnedUndo, uprightUndo, "undo in the drawing turned the other way")
        tap(element(FlowElement.markupCancel, in: app))
        XCTAssertTrue(waitUntilHittable(trash))
        let trashAfterDrawing = try settledPicture(of: trash)
        try expectSame(trashAfterDrawing, uprightTrash, "trash after the drawing")

        showShooting(in: app)
        let turnedRightAccept = try settledPicture(of: accept)
        try expectShootingTurned(turnedRightAccept, from: uprightShootingAccept)
        if !interfaceTurnsWithTheDevice {
            XCTAssertGreaterThan(try differingShare(turnedRightAccept, turnedLeftAccept), turnedShare)
        }

        openReview(in: app)
        XCUIDevice.shared.orientation = .portrait
        let reviewAcceptTurnedBack = try settledPicture(of: accept)
        try expectSame(reviewAcceptTurnedBack, uprightReviewAccept, "check mark in the review turned back")
        showShooting(in: app)
        let shootingAcceptTurnedBack = try settledPicture(of: accept)
        try expectSame(shootingAcceptTurnedBack, uprightShootingAccept, "check mark back in the shooting mode")
    }

    // MARK: - Helpers

    private func showShooting(in app: XCUIApplication) {
        tap(element(FlowElement.modeShooting, in: app))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
    }

    private func expectShootingTurned(_ turned: CGImage, from upright: CGImage) throws {
        let share = try differingShare(turned, upright)
        if interfaceTurnsWithTheDevice {
            XCTAssertLessThan(share, sameShare, "the shooting mode stands upright in an interface that turned")
        } else {
            XCTAssertGreaterThan(share, turnedShare, "the shooting mode turns its check mark with the phone")
        }
    }

    private func expectSame(_ picture: CGImage, _ upright: CGImage, _ what: String) throws {
        XCTAssertLessThan(try differingShare(picture, upright), sameShare, "\(what) stands upright")
    }

    /// A picture of the element once it stopped moving: two pictures in a row that do not differ. XCTest takes them
    /// while it waits, a moment apart.
    private func settledPicture(of element: XCUIElement) throws -> CGImage {
        XCTAssertTrue(waitUntilHittable(element))
        let settling = SettlingPicture()
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate { [self] _, _ in
                do {
                    let current = try picture(of: element)
                    defer { settling.last = current }
                    guard let last = settling.last, try differingShare(current, last) == 0 else { return false }
                    settling.settled = current
                    return true
                } catch {
                    settling.failure = error
                    return true
                }
            },
            object: nil
        )
        _ = XCTWaiter.wait(for: [settled], timeout: timeout)
        if let failure = settling.failure {
            throw failure
        }
        return try XCTUnwrap(settling.settled, "\(element) never stopped moving")
    }

    /// A picture of the element as the interface shows it: a screenshot of a turned interface comes with the turn as
    /// its orientation, which drawing it applies.
    private func picture(of element: XCUIElement) throws -> CGImage {
        let screenshot = element.screenshot().image
        let format = UIGraphicsImageRendererFormat()
        format.scale = screenshot.scale
        let upright = UIGraphicsImageRenderer(size: screenshot.size, format: format).image { _ in
            screenshot.draw(at: .zero)
        }
        return try XCTUnwrap(upright.cgImage, "no picture of \(element)")
    }

    /// The share of pixels whose colour differs by more than a trace between two pictures of one size. Pictures of
    /// another size differ entirely.
    private func differingShare(_ first: CGImage, _ second: CGImage) throws -> Double {
        guard first.width == second.width, first.height == second.height else { return 1 }
        let firstPixels = try pixels(of: first)
        let secondPixels = try pixels(of: second)
        let tolerance = 24
        var differing = 0
        for pixel in stride(from: 0, to: firstPixels.count, by: 4) {
            let isDifferent = (0..<3).contains { channel in
                abs(Int(firstPixels[pixel + channel]) - Int(secondPixels[pixel + channel])) > tolerance
            }
            if isDifferent {
                differing += 1
            }
        }
        return Double(differing) / Double(first.width * first.height)
    }

    private func pixels(of image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        try pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            let drawing = try XCTUnwrap(context, "cannot read the pixels of a picture")
            drawing.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }
}

/// The pictures of an element taken while XCTest waits for it to stop moving.
private final class SettlingPicture {
    /// The picture taken last, nil before the first.
    var last: CGImage?
    /// The first picture that did not differ from the one before it.
    var settled: CGImage?
    /// What went wrong while a picture was taken or compared.
    var failure: (any Error)?
}
