import XCTest

final class VroomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAppearsOnFirstLaunch() throws {
        let app = firstLaunchApp()
        app.launch()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDriveTabLaunchesWithSeededPreviewData() throws {
        let app = seededApp()
        app.launch()

        XCTAssertTrue(app.otherElements["Drive.Screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Night Loop"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStartAndStopDriveShowsSummary() throws {
        let app = seededApp()
        app.launch()

        let startButton = app.buttons["Start Drive"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let stopButton = app.buttons["End Drive"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        let activeStopButton = stopButton
        activeStopButton.tap()

        XCTAssertTrue(app.staticTexts["Drive saved"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryFilteringAndReplayFlow() throws {
        let app = seededApp()
        app.launch()

        app.buttons["History"].tap()
        let favorites = app.buttons["Saved"].firstMatch
        XCTAssertTrue(favorites.waitForExistence(timeout: 8))
        favorites.tap()

        let savedDrive = app.descendants(matching: .any)["History.Drive.SunsetCanyonRun"]
        let hiddenDrive = app.descendants(matching: .any)["History.Drive.NightLoop"]
        XCTAssertTrue(savedDrive.waitForExistence(timeout: 5))
        XCTAssertFalse(hiddenDrive.exists)
        XCTAssertTrue(app.otherElements["History.Preview.66666666-7777-8888-9999-AAAAAAAAAAAA"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6.3 km"].waitForExistence(timeout: 5))

        savedDrive.tap()
        let replayButton = app.buttons["DriveDetail.Replay"]
        XCTAssertTrue(replayButton.waitForExistence(timeout: 5))
        replayButton.tap()
        XCTAssertTrue(app.otherElements["Replay.Screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replay.StartOver"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replay.Follow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replay.Recenter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replay.Speed.1x"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGarageShowsPremiumAndVehicleEditor() throws {
        let app = seededApp()
        app.launch()

        app.buttons["Garage"].tap()
        XCTAssertTrue(app.buttons["Garage.Vehicle.Midnight"].waitForExistence(timeout: 8))
        let premiumButton = app.buttons["See Premium Plans"].firstMatch.exists
            ? app.buttons["See Premium Plans"].firstMatch
            : app.buttons["Manage Premium"].firstMatch
        if !premiumButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(premiumButton.waitForExistence(timeout: 8))

        premiumButton.tap()
        XCTAssertTrue(app.staticTexts["Premium"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        let settingsRow = app.staticTexts["Settings and privacy"].firstMatch
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5))
        settingsRow.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Garage.Vehicle.Midnight"].tap()
        XCTAssertTrue(app.buttons["Save vehicle"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testDriveScreenCanOpenConvoys() throws {
        let app = seededApp()
        app.launch()

        let convoysButton = app.buttons["Drive.ConvoysPreview"]
        XCTAssertTrue(convoysButton.waitForExistence(timeout: 5))
        convoysButton.tap()

        XCTAssertTrue(app.staticTexts["Convoys preview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Create room"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            seededApp().launch()
        }
    }

    @MainActor
    private func seededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITestingSeedPreviewData"]
        return app
    }

    @MainActor
    private func firstLaunchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITestingInMemoryStore"]
        return app
    }

}
