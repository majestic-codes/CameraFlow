//
//  CameraFlowUITestSupport.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 11.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The accessibility identifiers of `CameraIdentifier` and `FlowIdentifier` in the package, repeated as strings
/// because the test runner does not link the package.
enum FlowElement {
    static let viewfinder = "camera.viewfinder"
    static let shutter = "camera.shutter"
    static let more = "camera.more"
    static let flip = "camera.flip"
    static let flash = "camera.topBar.flash"
    static let live = "camera.topBar.live"
    static let dualCamera = "camera.topBar.dualCamera"
    static let dualCameraCircle = "camera.dualCameraCircle"
    static let save = "camera.topBar.save"
    static let zoomDial = "camera.zoomDial"
    static let focusReticle = "camera.focusReticle"
    static let countdown = "camera.countdown"
    static let notice = "camera.notice"
    static let retry = "camera.retry"
    static let openSettings = "camera.openSettings"
    static let panel = "camera.panel"
    static let subPanel = "camera.subpanel"
    static let subPanelBack = "camera.subpanel.back"
    static let subPanelTitle = "camera.subpanel.title"
    static let photoSize = "camera.subpanel.photoSize"
    static let onboarding = "camera.onboarding"
    static let onboardingTitle = "camera.onboarding.title"
    static let onboardingContinue = "camera.onboarding.continue"
    static let exit = "flow.exit"
    static let accept = "flow.accept"
    static let library = "flow.library"
    static let modeShooting = "flow.mode.shooting"
    static let modeReview = "flow.mode.review"
    static let badge = "flow.mode.badge"
    static let reviewDelete = "flow.review.delete"
    static let reviewCounter = "flow.review.counter"
    static let reviewMarkup = "flow.review.markup"
    static let reviewAdd = "flow.review.add"
    static let markupCancel = "flow.markup.cancel"
    static let markupUndo = "flow.markup.undo"
    static let markupRedo = "flow.markup.redo"
    static let markupDone = "flow.markup.done"
    static let markupCanvas = "flow.markup.canvas"

    static func lens(_ factor: String) -> String {
        "camera.lens." + factor
    }

    static func tile(_ setting: String) -> String {
        "camera.panel.tile." + setting
    }

    static func indicator(_ setting: String) -> String {
        "camera.topBar." + setting
    }

    static func reviewTile(_ number: Int) -> String {
        "flow.review.tile.\(number)"
    }
}

/// The accessibility identifiers of the example's start screen, repeated as strings from its `ContentView`.
enum ExampleElement {
    static let openCameraFlow = "example.openCameraFlow"
    static let openCameraFlowUIKit = "example.openCameraFlowUIKit"
    static let photoCount = "example.photoCount"
}

/// Launch arguments of the example that the driver passes by default and a test may pass others in place of.
enum ExampleArgument {
    /// Saving to the photo library off, which every launch gets unless it asks for saving.
    static let savingOff = ["-cameraFlowNoLibrarySave"]
}

/// What the test cases of the camera flow share: the launch over the simulated camera, the waits and the touch. A view
/// the flow conceals stays in the hierarchy the runner sees, so a control counts as shown when a touch reaches it
/// (`isHittable`), not when it exists.
@MainActor
protocol CameraFlowDriving {}

extension CameraFlowDriving where Self: XCTestCase {
    var timeout: TimeInterval {
        15
    }

    // MARK: - Launch

    /// Launches the flow over the simulated camera, in the language and the region given, English for the United
    /// States unless asked otherwise, whatever the simulator's are.
    ///
    /// Every launch starts from a fresh state unless asked otherwise: the example removes the preferences it stored and
    /// what the flow remembers before anything reads them, whatever an earlier test, passed or failed, left behind. A
    /// test that checks what a launch keeps for the next one launches the next one with `resetsState: false`. Unless
    /// asked otherwise the flow forgets the user's settings, gets no preferences an earlier launch stored and saves
    /// nothing to the photo library, so every test starts from the values of its arguments. The photos record no
    /// location unless asked, so the location access of the simulator never brings the flow's location step or the
    /// system's alert into a test about something else.
    func launchFlow(
        _ arguments: [String] = [],
        opening: [String] = ["-cameraFlow"],
        saving: [String] = ExampleArgument.savingOff,
        language: String = "en",
        region: String = "US",
        resetsState: Bool = true,
        usesMemory: Bool = false,
        appliesStoredPreferences: Bool = false,
        recordsLocation: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = ["-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)"]
        let reset = resetsState ? ["-cameraFlowResetState"] : []
        let memory = usesMemory ? [] : ["-cameraFlowNoMemory"]
        let preferences = appliesStoredPreferences ? [] : ["-cameraFlowNoPreferences"]
        let location = recordsLocation ? [] : ["-cameraFlowNoLocation"]
        let example = opening + ["-cameraFlowSimulated"] + saving + reset + memory + preferences + location
        app.launchArguments = locale + example + arguments
        app.launch()
        return app
    }

    /// Launches the flow and waits for the camera to take the given number of photos by itself.
    func launchFlowWithPhotos(
        _ count: Int,
        _ arguments: [String] = [],
        saving: [String] = ExampleArgument.savingOff,
        language: String = "en",
        region: String = "US"
    ) -> XCUIApplication {
        let capture = ["-cameraFlowAutoCapture", String(count)]
        let app = launchFlow(capture + arguments, saving: saving, language: language, region: region)
        XCTAssertTrue(waitForValue(String(count), of: element(FlowElement.badge, in: app), timeout: 30))
        return app
    }

    /// Launches the flow with photos and opens the review, which shows the last of them.
    func launchReview(
        photoCount: Int,
        _ arguments: [String] = [],
        language: String = "en",
        region: String = "US"
    ) -> XCUIApplication {
        let app = launchFlowWithPhotos(photoCount, arguments, language: language, region: region)
        openReview(in: app)
        return app
    }

    func openReview(in app: XCUIApplication) {
        let review = element(FlowElement.modeReview, in: app)
        XCTAssertTrue(waitUntilEnabled(review))
        tap(review)
        XCTAssertTrue(waitUntilSelected(review))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.reviewDelete, in: app)))
    }

    // MARK: - Elements

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func option(_ name: String, in app: XCUIApplication) -> XCUIElement {
        element("camera.subpanel.option." + name, in: app)
    }

    // MARK: - Waits

    func wait(for element: XCUIElement, until format: String, timeout: TimeInterval? = nil) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout ?? self.timeout) == .completed
    }

    /// Waits for an element to be the one a touch at its middle reaches, as it is once a transition over it ended.
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        wait(for: element, until: "exists == true AND isHittable == true", timeout: timeout)
    }

    /// Waits for an element to be gone or out of reach of a touch: covered, faded out or moved off the screen.
    func waitUntilNotHittable(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        wait(for: element, until: "exists == false OR isHittable == false", timeout: timeout)
    }

    func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        wait(for: element, until: "exists == true AND isEnabled == true", timeout: timeout)
    }

    func waitUntilDisabled(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        wait(for: element, until: "exists == true AND isEnabled == false", timeout: timeout)
    }

    func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        wait(for: element, until: "exists == true AND isSelected == true", timeout: timeout)
    }

    func waitForValue(_ value: String, of element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout ?? self.timeout) == .completed
    }

    func waitForLabel(_ label: String, of element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout ?? self.timeout) == .completed
    }

    /// Waits for the label of an element to be another one than the given one.
    func waitForLabel(of element: XCUIElement, toChangeFrom label: String, timeout: TimeInterval? = nil) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND label != %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout ?? self.timeout) == .completed
    }

    /// Waits for the start screen of the example to count the photos it kept, such as "1 photo" or "2 photos".
    func waitForPhotoCount(_ count: Int, in app: XCUIApplication) -> Bool {
        let label = count == 1 ? "1 photo" : "\(count) photos"
        return waitForLabel(label, of: element(ExampleElement.photoCount, in: app))
    }

    // MARK: - Touch

    /// Taps the middle of an element by its coordinates, for the ones the runner never finds hittable: a lens button,
    /// whose touch goes to the gesture surface over the row, the Settings button of a refused camera, and a photo of
    /// the system's picker.
    func tapMiddle(of element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Taps an element once a touch reaches it.
    func tap(_ element: XCUIElement) {
        XCTAssertTrue(waitUntilHittable(element), "nothing to tap: \(element)")
        element.tap()
    }

    /// Takes a photo with the shutter and waits for it to land in the set.
    func takePhoto(in app: XCUIApplication, expecting count: Int) {
        let shutter = element(FlowElement.shutter, in: app)
        XCTAssertTrue(waitUntilEnabled(shutter))
        tap(shutter)
        XCTAssertTrue(waitForValue(String(count), of: element(FlowElement.badge, in: app)))
    }

    /// Keeps a picture of the screen with the result of the test.
    func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
