import XCTest

/// Rotation stands in for the window resizes an iPhone Duo applies when the app
/// moves between its 466 × 678 and 669 × 951 point displays.
@MainActor
final class AdaptiveLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTreatmentPlanDraftSurvivesRotationAndStaysReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["Add new"].tap()
        let planChoice = app.buttons["add.choice.Treatment Plan"]
        XCTAssertTrue(planChoice.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["add.choice.Medicine"].exists)
        planChoice.tap()

        let planField = app.textFields["plan.title"]
        XCTAssertTrue(planField.waitForExistence(timeout: 3))
        planField.tap()
        planField.typeText("Rotation Plan")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(planField.value as? String, "Rotation Plan")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(planField.value as? String, "Rotation Plan")

        app.buttons["wizard.next"].tap()
        XCTAssertTrue(app.staticTexts["All Medicines"].waitForExistence(timeout: 3))
        app.buttons["wizard.next"].tap()

        let prescriberField = app.textFields["plan.prescriber"]
        XCTAssertTrue(prescriberField.waitForExistence(timeout: 3))
        prescriberField.tap()
        prescriberField.typeText("Dr. Rivera")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(prescriberField.value as? String, "Dr. Rivera")
        app.buttons["wizard.save"].tap()

        XCTAssertTrue(app.staticTexts["Rotation Plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dr. Rivera"].exists)
    }
}
