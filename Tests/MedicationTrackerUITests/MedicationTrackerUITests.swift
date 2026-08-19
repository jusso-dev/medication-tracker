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
        app.buttons["Scan medicine label"].tap()
        XCTAssertTrue(app.buttons["Choose Photo"].waitForExistence(timeout: 3))
        app.buttons["scan.close"].tap()

        nameField.tap()
        nameField.typeText("Ibuprofen")
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["Set your dosage"].waitForExistence(timeout: 3))
        app.buttons["dose.unit.mg"].tap()
        app.buttons["dose.key.4"].tap()
        app.buttons["dose.key.0"].tap()
        app.buttons["dose.key.0"].tap()
        let clearDose = app.buttons["dose.clear"]
        for _ in 0..<2 where !clearDose.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(clearDose.isEnabled)
        clearDose.tap()
        XCTAssertFalse(clearDose.isEnabled)
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

    func testAustralianMedicineLookupFillsGenericName() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["Add new"].tap()
        app.buttons["add.choice.Medicine"].tap()

        let nameField = app.textFields["medicine.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Panadol")
        let done = app.keyboards.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        done.tap()

        let menu = app.buttons["medicine.lookup.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        for _ in 0..<3 where !menu.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(menu.isHittable)
        menu.tap()
        let result = app.buttons["Paracetamol"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        result.tap()
        app.buttons["wizard.next"].tap()
        XCTAssertTrue(app.staticTexts["Set your dosage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Paracetamol"].exists)
    }

    func testScheduledMedicineSelectsAllDaysAndContinues() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        app.buttons["Add new"].tap()
        app.buttons["add.choice.Medicine"].tap()
        let nameField = app.textFields["medicine.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test Medicine")
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["Set your dosage"].waitForExistence(timeout: 3))
        app.buttons["dose.key.1"].tap()
        app.buttons["wizard.next"].tap()

        XCTAssertTrue(app.staticTexts["Any schedule?"].waitForExistence(timeout: 3))
        app.buttons["schedule.all-days"].tap()
        app.buttons["wizard.next"].tap()
        let addTime = app.buttons["Add 8:00 a.m."]
        XCTAssertTrue(addTime.waitForExistence(timeout: 3))

        addTime.tap()
        app.buttons["wizard.next"].tap()
        XCTAssertTrue(
            app.staticTexts["How long will you take it?"].waitForExistence(timeout: 3)
        )
    }

    func testSeededDataWalksCatalogDetailsTodayAndHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Tooth Infection"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ibuprofen"].exists)
        app.staticTexts["Amoxicillin"].tap()

        XCTAssertTrue(app.staticTexts["Medication"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Daily intake"].exists)
        XCTAssertTrue(app.staticTexts["Weekly schedule"].exists)
        XCTAssertTrue(app.staticTexts["Package expiry"].exists)
        XCTAssertTrue(app.staticTexts["Refill Scripts"].exists)

        app.buttons["refill.script.RX-TEST"].tap()
        XCTAssertTrue(app.staticTexts["Refill Script"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Valid"].exists)
        XCTAssertTrue(app.staticTexts["3 repeats remaining"].exists)
        app.buttons["refill.review.close"].tap()
        app.buttons["Close"].firstMatch.tap()

        app.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Due now"].waitForExistence(timeout: 3))
        app.buttons["Take"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Taken"].waitForExistence(timeout: 3))

        let logDose = app.buttons["Log dose"]
        XCTAssertTrue(logDose.waitForExistence(timeout: 3))
        logDose.tap()
        XCTAssertTrue(app.buttons["Daily limit reached"].waitForExistence(timeout: 3))

        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Past medications"].waitForExistence(timeout: 3))
        app.staticTexts["Paracetamol"].tap()
        XCTAssertTrue(app.staticTexts["Medication"].waitForExistence(timeout: 3))
        let restart = app.buttons["Restart"]
        for _ in 0..<4 where !restart.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(restart.isHittable)
        restart.tap()
        XCTAssertTrue(app.staticTexts["Medications Catalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Paracetamol"].exists)
    }

    func testIncomingCareSnapshotCanBeReviewedAndImported() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-import"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Review Care Snapshot"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Shared Cetirizine"].exists)
        app.buttons["care-share.import"].tap()
        XCTAssertTrue(app.staticTexts["Care snapshot imported"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Medicines added"].exists)
        app.buttons["care-share.import.done"].tap()
        XCTAssertTrue(app.staticTexts["Medications Catalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Shared Cetirizine"].exists)
    }

    func testSettingsCanScrollToSafetyDisclaimer() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-seed"]
        app.launch()

        app.buttons["Settings"].tap()
        let disclaimer = app.staticTexts[
            "Not medical advice and not a substitute for a pharmacist or a doctor."
        ]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        let careShare = app.buttons["care-share.settings"]
        for _ in 0..<4 where !careShare.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(careShare.isHittable)
        careShare.tap()
        XCTAssertTrue(app.staticTexts["Care Share"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bring the iPhones together"].exists)
        XCTAssertTrue(app.staticTexts["None selected."].exists)
        XCTAssertTrue(app.buttons["care-share.open"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()

        for _ in 0..<4 where !disclaimer.isHittable {
            scrollView.swipeUp()
        }

        XCTAssertTrue(disclaimer.isHittable)
    }
}
