import XCTest

final class VroomUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAppearsOnFirstLaunch() throws {
        let app = firstLaunchApp()
        app.launch()

        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
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

        let startButton = app.buttons["Start drive"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let stopButton = app.buttons["Stop drive"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5) || app.buttons["Stop and save drive"].waitForExistence(timeout: 5))
        let activeStopButton = app.buttons["Stop and save drive"].exists ? app.buttons["Stop and save drive"] : stopButton
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

        XCTAssertTrue(app.staticTexts["Sunset Canyon Run"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Night Loop"].exists)

        let replayButton = app.buttons["Replay drive"].firstMatch
        XCTAssertTrue(replayButton.waitForExistence(timeout: 5))
        replayButton.tap()
        XCTAssertTrue(app.otherElements["Replay.Screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Replay.StartOver"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGarageShowsPremiumAndVehicleEditor() throws {
        let app = seededApp()
        app.launch()

        app.buttons["Garage"].tap()
        XCTAssertTrue(app.buttons["Garage.Vehicle.Midnight"].waitForExistence(timeout: 8))
        let premiumButton = app.buttons["Upgrade to Premium"].firstMatch.exists
            ? app.buttons["Upgrade to Premium"].firstMatch
            : app.buttons["Manage Premium"].firstMatch
        if !premiumButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(premiumButton.waitForExistence(timeout: 8))

        premiumButton.tap()
        XCTAssertTrue(app.staticTexts["Premium"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["Garage.Vehicle.Midnight"].tap()
        XCTAssertTrue(app.buttons["Save vehicle"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testDriveScreenCanOpenConvoys() throws {
        let app = seededApp()
        app.launch()

        let convoysButton = app.buttons["Drive.Convoys"]
        XCTAssertTrue(convoysButton.waitForExistence(timeout: 5))
        convoysButton.tap()

        XCTAssertTrue(app.staticTexts["Convoys"].waitForExistence(timeout: 5) || app.staticTexts["Convoys beta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create room"].waitForExistence(timeout: 5))
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
