import XCTest

@MainActor
final class MedicationTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddChooserStartsMedicineWizardAndSavesAsNeededMedicine() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["Add new"].tap()
        XCTAssertTrue(app.staticTexts["Add new"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["add.choice.Medicine"].exists)
        XCTAssertTrue(app.buttons["add.choice.Treatment Plan"].exists)

        app.buttons["add.choice.Medicine"].tap()
        let nameField = app.textFields["medicine.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Ibuprofen")
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["Set your dosage"].waitForExistence(timeout: 3))
        app.buttons["dose.unit.mg"].tap()
        app.buttons["dose.key.4"].tap()
        app.buttons["dose.key.0"].tap()
        app.buttons["dose.key.0"].tap()
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["Any schedule?"].waitForExistence(timeout: 3))
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["How long will you take it?"].waitForExistence(timeout: 3))
        app.buttons["duration.ongoing"].tap()
        app.buttons["wizard.save"].tap()

        XCTAssertTrue(app.staticTexts["Ibuprofen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["400 mg"].exists)
        XCTAssertTrue(app.staticTexts["As needed"].exists)

        app.buttons["Add new"].tap()
        app.buttons["add.choice.Treatment Plan"].tap()
        let planField = app.textFields["plan.title"]
        XCTAssertTrue(planField.waitForExistence(timeout: 3))
        planField.tap()
        planField.typeText("Tooth Infection")
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["All Medicines"].waitForExistence(timeout: 3))
        app.buttons["plan.add.Ibuprofen"].tap()
        app.buttons["wizard.next"].tap()

        let prescriberField = app.textFields["plan.prescriber"]
        XCTAssertTrue(prescriberField.waitForExistence(timeout: 3))
        prescriberField.tap()
        prescriberField.typeText("Dr. Chen")
        app.buttons["wizard.save"].tap()

        XCTAssertTrue(app.staticTexts["Tooth Infection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dr. Chen"].exists)
        app.buttons["plan.card.Tooth Infection"].tap()
        XCTAssertTrue(app.staticTexts["Treatment plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Prescribed by"].exists)
    }
}
