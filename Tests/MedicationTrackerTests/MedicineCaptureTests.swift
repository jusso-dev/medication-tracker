import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@Suite("Medicine capture")
struct MedicineCaptureTests {
    @Test("Australian brand search returns the generic medicine")
    func catalogueBrandSearch() {
        let result = AustralianMedicineCatalogue.search("Panadol")
        #expect(result.first?.genericName == "Paracetamol")
    }

    @Test("Catalogue OCR matching prefers the longest medicine name")
    func catalogueLongestMatch() {
        let result = AustralianMedicineCatalogue.match(
            in: "AMOXICILLIN WITH CLAVULANIC ACID 875 MG"
        )
        #expect(result?.genericName == "Amoxicillin with clavulanic acid")
    }

    @Test("OCR parser extracts medicine strength and package expiry")
    func medicineLabelParsing() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let result = MedicationOCRService.parse(
            lines: [
                "AMOXIL",
                "30 TABLETS",
                "AMOXICILLIN 500 mg",
                "EXP 08/2027",
                "BATCH A1234"
            ],
            calendar: calendar
        )

        #expect(result.medicineName == "Amoxicillin")
        #expect(result.amount == 500)
        #expect(result.unit == .mg)
        let expiryDate = try #require(result.expiryDate)
        #expect(calendar.component(.day, from: expiryDate) == 31)
        #expect(calendar.component(.month, from: expiryDate) == 8)
        #expect(calendar.component(.year, from: expiryDate) == 2027)
    }

    @Test("OCR parser rejects invalid expiry dates")
    func invalidExpiryDates() {
        #expect(MedicationOCRService.parse(lines: ["EXP 13/2027"]).expiryDate == nil)
        #expect(MedicationOCRService.parse(lines: ["EXP 31/02/2027"]).expiryDate == nil)
    }

    @Test("OCR parser extracts refill-script fields")
    func prescriptionParsing() {
        let result = MedicationOCRService.parse(lines: [
            "SCRIPT NO ABCD-1234",
            "REPEATS REMAINING 3",
            "TOTAL REPEATS 5",
            "DR Jane Chen",
            "VALID UNTIL 25/12/2027"
        ])

        #expect(result.scriptNumber == "ABCD-1234")
        #expect(result.repeatsRemaining == 3)
        #expect(result.repeatsAuthorised == 5)
        #expect(result.prescriber == "Jane Chen")
    }

    @Test("OCR distinguishes package volume from liquid strength")
    func liquidStrengthParsing() {
        let result = MedicationOCRService.parse(lines: [
            "CHEMIST WAREHOUSE 100 mL",
            "DOSE FORM ORAL SOLUTION 100 mL",
            "CUSTOMMED 250 mg/5 mL",
            "ORAL SUSPENSION"
        ])

        #expect(result.medicineName == "Custommed")
        #expect(result.amount == 250)
        #expect(result.unit == .mg)
    }

    @Test("OCR reads explicit volume directions without using bottle size")
    func volumeDoseDirection() {
        let result = MedicationOCRService.parse(lines: [
            "CUSTOM LIQUID",
            "TAKE 5 mL TWICE DAILY",
            "100 mL BOTTLE"
        ])

        #expect(result.medicineName == "Custom Liquid")
        #expect(result.amount == 5)
        #expect(result.unit == .mL)

        let directionsOnly = MedicationOCRService.parse(lines: [
            "GIVE 5 mL TWICE DAILY"
        ])
        #expect(directionsOnly.medicineName == nil)
        #expect(directionsOnly.amount == 5)

        let lotrel = MedicationOCRService.parse(lines: [
            "LOTREL 5 mg TABLETS"
        ])
        #expect(lotrel.medicineName == "Lotrel")
    }

    @Test("OCR can use a safe name adjacent to a strength line")
    func adjacentMedicineName() {
        let result = MedicationOCRService.parse(lines: [
            "CUSTOMMED",
            "500 mg TABLETS"
        ])

        #expect(result.medicineName == "Custommed")
        #expect(result.amount == 500)
    }

    @Test("OCR prioritises explicitly remaining repeats")
    func totalRepeatsBeforeRemaining() {
        let result = MedicationOCRService.parse(lines: [
            "TOTAL REPEATS 5",
            "REPEATS REMAINING 3"
        ])

        #expect(result.repeatsAuthorised == 5)
        #expect(result.repeatsRemaining == 3)
    }

    @Test("OCR does not use pharmacy or patient names as medicine names")
    func unsafeFallbackName() {
        let result = MedicationOCRService.parse(lines: [
            "SUNSHINE PHARMACY",
            "PATIENT JOHN SMITH",
            "EXP 08/2027"
        ])

        #expect(result.medicineName == nil)
    }

    @Test("Refill-script status uses explicit expiry and repeats")
    func refillStatus() {
        let future = Calendar.current.date(
            from: DateComponents(year: 2099, month: 1, day: 1)
        )
        let past = Calendar.current.date(
            from: DateComponents(year: 2020, month: 1, day: 1)
        )

        #expect(RefillScript(expiryDate: future, repeatsRemaining: 2).status == .valid)
        #expect(RefillScript(expiryDate: past, repeatsRemaining: 2).status == .expired)
        #expect(RefillScript(repeatsRemaining: 2).status == .reviewNeeded)
        #expect(RefillScript(expiryDate: future, repeatsRemaining: 0).status == .noRepeats)
    }
}

@MainActor
@Suite("Refill-script persistence")
struct RefillScriptPersistenceTests {
    @Test("Script is linked back to its medicine")
    func inverseRelationship() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Medicine.self,
            TreatmentPlan.self,
            DoseEvent.self,
            RefillScript.self,
            configurations: configuration
        )
        let medicine = Medicine(
            name: "Amoxicillin",
            amount: 500,
            unit: .mg,
            asNeeded: true,
            startDate: .now
        )
        let script = RefillScript(
            medicine: medicine,
            expiryDate: Calendar.current.date(
                from: DateComponents(year: 2099, month: 1, day: 1)
            ),
            repeatsAuthorised: 5,
            repeatsRemaining: 3,
            lastReviewedAt: .now
        )
        container.mainContext.insert(medicine)
        container.mainContext.insert(script)
        try container.mainContext.save()

        #expect(medicine.refillScripts.contains { $0.id == script.id })
    }

    @Test("Legacy expiry dates migrate to calendar-day storage")
    func calendarDayMigration() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Medicine.self,
            TreatmentPlan.self,
            DoseEvent.self,
            RefillScript.self,
            configurations: configuration
        )
        let expiry = Calendar.current.date(
            from: DateComponents(year: 2028, month: 3, day: 15)
        )
        let start = Calendar.current.date(
            from: DateComponents(year: 2028, month: 2, day: 1)
        ) ?? .now
        let medicine = Medicine(
            name: "Test",
            amount: 1,
            unit: .tablet,
            asNeeded: true,
            startDate: .now
        )
        medicine.packageExpiryDay = nil
        medicine.legacyPackageExpiryDate = expiry
        medicine.startDay = nil
        medicine.legacyStartDate = start
        let script = RefillScript(medicine: medicine, repeatsRemaining: 1)
        script.expiryDay = nil
        script.legacyExpiryDate = expiry
        let plan = TreatmentPlan(title: "Legacy")
        plan.startDay = nil
        plan.legacyStartDate = start
        plan.endDay = nil
        plan.legacyEndDate = expiry
        container.mainContext.insert(medicine)
        container.mainContext.insert(script)
        container.mainContext.insert(plan)
        try container.mainContext.save()

        try CalendarDayMigration.migrateIfNeeded(
            context: container.mainContext
        )

        #expect(medicine.packageExpiryDay?.year == 2028)
        #expect(medicine.packageExpiryDay?.month == 3)
        #expect(medicine.packageExpiryDay?.day == 15)
        #expect(medicine.legacyPackageExpiryDate == nil)
        #expect(medicine.startDay?.day == 1)
        #expect(script.expiryDay == medicine.packageExpiryDay)
        #expect(script.legacyExpiryDate == nil)
        #expect(plan.startDay?.day == 1)
        #expect(plan.endDay?.day == 15)
        #expect(plan.legacyStartDate == nil)
        #expect(plan.legacyEndDate == nil)
    }
}
