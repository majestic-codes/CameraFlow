//
//  CameraFlowOnboardingUITests.swift
//  CameraFlow
//
//  Created by Yevhenii Kalashnikov on 12.11.2026.
//  Copyright © 2026 Yevhenii Kalashnikov.
//

import XCTest

/// The introduction the flow shows before the camera, the location and the photo library are asked for.
@MainActor
final class CameraFlowOnboardingUITests: XCTestCase, CameraFlowDriving {
    private let locationTitle = "Photo Locations"

    override func setUp() {
        continueAfterFailure = false
    }

    func testCameraThatWasNotAskedForOpensWithTheIntroduction() throws {
        let app = launchFlow(["-cameraFlowAccess", "camera"])

        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForExistence(timeout: timeout))
        XCTAssertEqual(element(FlowElement.onboardingTitle, in: app).label, "Add Photos")
        XCTAssertTrue(app.staticTexts["Pick photos without giving access to your whole library."].exists)
        XCTAssertTrue(element(FlowElement.onboardingContinue, in: app).isHittable)
        XCTAssertFalse(element(FlowElement.shutter, in: app).isHittable)
    }

    func testContinueOfTheIntroductionLeadsToTheCamera() throws {
        let app = launchFlow(["-cameraFlowAccess", "camera"])

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.exit, in: app).isHittable)
    }

    func testLibraryStepFollowsTheCameraWhereTheFlowSavesAndContinueGoesOnToTheCamera() throws {
        let app = launchFlow(["-cameraFlowAccess", "library"], saving: ["-cameraFlowSaveToLibrary"])

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(app.staticTexts["Save to Photos"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["The app can add photos but can’t see your library."].exists)
        XCTAssertTrue(waitUntilHittable(element(FlowElement.onboardingContinue, in: app)))
        attachScreenshot(named: "onboarding-library-en")
        tap(element(FlowElement.onboardingContinue, in: app))
        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
    }

    func testLibraryStepFollowsTheLocationStepWhenTheCameraWasGrantedBefore() throws {
        let saving = ["-cameraFlowSaveToLibrary"]
        let app = launchFlow(["-cameraFlowAccess", "locationAndLibrary"], saving: saving, recordsLocation: true)
        let title = element(FlowElement.onboardingTitle, in: app)
        let next = element(FlowElement.onboardingContinue, in: app)
        XCTAssertTrue(waitForLabel(locationTitle, of: title))

        tap(next)
        XCTAssertTrue(waitForLabel("Save to Photos", of: title))
        XCTAssertFalse(element(FlowElement.shutter, in: app).isHittable)

        tap(next)
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
    }

    func testLibraryStepComesAloneWhenOnlyTheLibraryWasNotAskedFor() throws {
        let saving = ["-cameraFlowSaveToLibrary"]
        let app = launchFlow(["-cameraFlowAccess", "libraryAlone"], saving: saving, recordsLocation: true)

        XCTAssertTrue(waitForLabel("Save to Photos", of: element(FlowElement.onboardingTitle, in: app)))
        XCTAssertTrue(app.staticTexts["The app can add photos but can’t see your library."].exists)
        XCTAssertFalse(element(FlowElement.shutter, in: app).isHittable)
        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
    }

    func testCameraGrantedBeforeWithSavingOffHasNoLibraryStep() throws {
        let app = launchFlow(["-cameraFlowAccess", "libraryAlone"], recordsLocation: true)

        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.onboarding, in: app).exists)
    }

    func testFlowThatNeverSavesHasNoLibraryStep() throws {
        let app = launchFlow(["-cameraFlowAccess", "library", "-cameraFlowLock", "save"])

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
    }

    func testFlowThatOpensWithSavingOffHasNoLibraryStep() throws {
        let app = launchFlow(["-cameraFlowAccess", "library"])

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.shutter, in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
    }

    func testCameraRefusedAtTheIntroductionShowsItsFailureWithTheWayToSettings() throws {
        let app = launchFlow(["-cameraFlowAccess", "denied"])

        tap(element(FlowElement.onboardingContinue, in: app))

        let openSettings = element(FlowElement.openSettings, in: app)
        XCTAssertTrue(openSettings.waitForExistence(timeout: timeout))
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.exit, in: app)))
        tapMiddle(of: openSettings)
        let systemSettings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(systemSettings.wait(for: .runningForeground, timeout: timeout))
    }

    func testCameraWithAccessOpensWithoutTheIntroduction() throws {
        let app = launchFlow()

        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.onboarding, in: app).exists)
    }

    func testIntroductionTurnedOffOpensTheCamera() throws {
        let app = launchFlow(["-cameraFlowAccess", "camera", "-cameraFlowNoOnboarding"])

        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.onboarding, in: app).exists)
    }

    func testIntroductionInUkrainian() throws {
        let app = launchFlow(["-cameraFlowAccess", "camera"], language: "uk", region: "UA")

        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForExistence(timeout: timeout))
        XCTAssertEqual(element(FlowElement.onboardingTitle, in: app).label, "Додавання фото")
        XCTAssertEqual(element(FlowElement.onboardingContinue, in: app).label, "Далі")
    }

    func testLibraryStepInUkrainian() throws {
        let saving = ["-cameraFlowSaveToLibrary"]
        let app = launchFlow(["-cameraFlowAccess", "library"], saving: saving, language: "uk", region: "UA")

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(app.staticTexts["Зберегти до Фотографій"].waitForExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.onboardingContinue, in: app)))
        attachScreenshot(named: "onboarding-library-uk")
    }

    // MARK: - The location

    func testCameraLocationAndLibraryStepsFollowOneAnotherWithContinue() throws {
        let saving = ["-cameraFlowSaveToLibrary"]
        let app = launchFlow(["-cameraFlowAccess", "all"], saving: saving, recordsLocation: true)
        let title = element(FlowElement.onboardingTitle, in: app)
        let next = element(FlowElement.onboardingContinue, in: app)
        XCTAssertTrue(waitForLabel("Add Photos", of: title))

        tap(next)
        XCTAssertTrue(waitForLabel(locationTitle, of: title))
        XCTAssertTrue(app.staticTexts["Each photo you take records the place where it was taken."].exists)
        XCTAssertEqual(next.label, "Continue")
        XCTAssertFalse(element(FlowElement.shutter, in: app).isHittable)

        tap(next)
        XCTAssertTrue(waitForLabel("Save to Photos", of: title))

        tap(next)
        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
    }

    func testLocationStepComesAloneWhenTheCameraWasGrantedBefore() throws {
        let saving = ["-cameraFlowSaveToLibrary"]
        let app = launchFlow(["-cameraFlowAccess", "location"], saving: saving, recordsLocation: true)

        XCTAssertTrue(waitForLabel(locationTitle, of: element(FlowElement.onboardingTitle, in: app)))
        XCTAssertTrue(app.staticTexts["Without location access, photos are taken just the same."].exists)
        XCTAssertFalse(element(FlowElement.shutter, in: app).isHittable)
        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
    }

    func testRefusedLocationGoesOnToTheCamera() throws {
        let app = launchFlow(["-cameraFlowAccess", "locationDenied"], recordsLocation: true)
        XCTAssertTrue(waitForLabel(locationTitle, of: element(FlowElement.onboardingTitle, in: app)))

        tap(element(FlowElement.onboardingContinue, in: app))

        XCTAssertTrue(element(FlowElement.onboarding, in: app).waitForNonExistence(timeout: timeout))
        takePhoto(in: app, expecting: 1)
    }

    func testFlowWithoutLocationHasNoLocationStep() throws {
        let app = launchFlow(["-cameraFlowAccess", "location"])

        XCTAssertTrue(waitUntilHittable(element(FlowElement.shutter, in: app)))
        XCTAssertFalse(element(FlowElement.onboarding, in: app).exists)
    }

    func testLocationStepInUkrainian() throws {
        let arguments = ["-cameraFlowAccess", "location"]
        let app = launchFlow(arguments, language: "uk", region: "UA", recordsLocation: true)

        XCTAssertTrue(waitForLabel("Геопозиція фото", of: element(FlowElement.onboardingTitle, in: app)))
        XCTAssertEqual(element(FlowElement.onboardingContinue, in: app).label, "Далі")
        attachScreenshot(named: "onboarding-location-uk")
    }
}
