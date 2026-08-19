import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@MainActor
@Suite("Care sharing")
struct CareShareTests {
    @Test("Care snapshot round-trips and imports with reminders off")
    func roundTripAndImport() throws {
        let source = try makeContainer()
        let plan = TreatmentPlan(
            title: "Recovery",
            prescriber: "Dr. Chen"
        )
        let medicine = Medicine(
            name: "Amoxicillin",
            amount: 500,
            unit: .mg,
            asNeeded: false,
            daysOfWeek: Array(1...7),
            times: [480, 960],
            startDate: .now,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            remindersOn: true,
            notes: "With food",
            plan: plan
        )
        let script = RefillScript(
            medicine: medicine,
            scriptNumber: "RX-1234",
            expiryDate: Calendar.current.date(byAdding: .year, value: 1, to: .now),
            repeatsAuthorised: 3,
            repeatsRemaining: 2,
            lastReviewedAt: .now
        )
        source.mainContext.insert(plan)
        source.mainContext.insert(medicine)
        source.mainContext.insert(script)
        try source.mainContext.save()

        let redactedPackage = CareShareService.makePackage(
            medicines: [medicine],
            treatmentPlans: [plan]
        )
        #expect(redactedPackage.medicines.first?.notes == nil)
        #expect(redactedPackage.medicines.first?.quantityRemaining == nil)
        #expect(redactedPackage.medicines.first?.refillScripts.isEmpty == true)
        #expect(redactedPackage.treatmentPlans.first?.prescriber == nil)

        let package = CareShareService.makePackage(
            medicines: [medicine],
            treatmentPlans: [plan],
            options: CareShareOptions(
                includeNotes: true,
                includeInventory: true,
                includeRefillScripts: true,
                includePrescriberNames: true
            )
        )
        let decoded = try CareShareCodec.decode(CareShareCodec.encode(package))
        #expect(decoded.medicines.count == 1)
        #expect(decoded.medicines.first?.refillScripts.count == 1)

        let destination = try makeContainer()
        let historicalStart = Date.now.addingTimeInterval(-20 * 86_400).startOfDay
        let historicalEnd = Date.now.addingTimeInterval(-10 * 86_400).startOfDay
        let historicalPlan = TreatmentPlan(title: "Completed course", status: .completed)
        historicalPlan.startDate = historicalStart
        historicalPlan.endDate = historicalEnd
        destination.mainContext.insert(historicalPlan)
        try destination.mainContext.save()

        let summary = try CareShareService.importPackage(
            decoded,
            context: destination.mainContext
        )
        let imported = try #require(
            destination.mainContext.fetch(FetchDescriptor<Medicine>()).first
        )

        #expect(summary.addedMedicines == 1)
        #expect(summary.addedRefillScripts == 1)
        #expect(imported.name == "Amoxicillin")
        #expect(imported.remindersOn == false)
        #expect(imported.plan?.title == "Recovery")
        #expect(imported.refillScripts.first?.scriptNumber == "RX-1234")
        #expect(historicalPlan.startDate == historicalStart)
        #expect(historicalPlan.endDate == historicalEnd)

        let duplicateSummary = try CareShareService.importPackage(
            decoded,
            context: destination.mainContext
        )
        #expect(duplicateSummary.addedMedicines == 0)
        #expect(duplicateSummary.skippedMedicines == 1)

        let completedPlan = try #require(imported.plan)
        completedPlan.status = .completed
        completedPlan.startDate = historicalStart
        completedPlan.endDate = historicalEnd
        try destination.mainContext.save()

        let original = try #require(decoded.medicines.first)
        let additional = SharedMedicine(
            id: UUID(),
            name: original.name,
            amount: original.amount,
            unitRawValue: original.unitRawValue,
            asNeeded: original.asNeeded,
            daysOfWeek: original.daysOfWeek,
            times: original.times,
            intervalMinutes: original.intervalMinutes,
            intervalLinked: original.intervalLinked,
            startDate: original.startDate,
            endDate: original.endDate,
            notes: original.notes,
            dailyCap: original.dailyCap,
            quantityRemaining: original.quantityRemaining,
            refillAt: original.refillAt,
            packageExpiryDate: original.packageExpiryDate,
            planID: original.planID,
            refillScripts: []
        )
        let laterPackage = CareSharePackage(
            medicines: [additional],
            treatmentPlans: decoded.treatmentPlans
        )
        _ = try CareShareService.importPackage(
            laterPackage,
            context: destination.mainContext
        )
        let laterMedicine = try #require(
            destination.mainContext.fetch(FetchDescriptor<Medicine>())
                .first { $0.id == additional.id }
        )
        #expect(laterMedicine.plan?.status == .active)
        #expect(laterMedicine.plan?.id != completedPlan.id)
        #expect(completedPlan.startDate == historicalStart)
        #expect(completedPlan.endDate == historicalEnd)
    }

    @Test("Care snapshot rejects unsupported schema")
    func unsupportedSchema() {
        let package = CareSharePackage(
            schemaVersion: 99,
            medicines: [],
            treatmentPlans: []
        )
        #expect(throws: CareShareError.self) {
            try CareShareCodec.validate(package)
        }
    }

    @Test("Date-only fields retain their calendar day across time zones")
    func calendarDateAcrossTimeZones() throws {
        let sydney = try #require(TimeZone(identifier: "Australia/Sydney"))
        let losAngeles = try #require(
            TimeZone(identifier: "America/Los_Angeles")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sydney
        let sourceDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20))
        )

        let shared = CalendarDay(sourceDate, timeZone: sydney)
        let destinationDate = try #require(shared.date(timeZone: losAngeles))
        calendar.timeZone = losAngeles
        let result = calendar.dateComponents(
            [.year, .month, .day],
            from: destinationDate
        )

        #expect(result.year == 2026)
        #expect(result.month == 8)
        #expect(result.day == 20)
    }

    @Test("Care snapshot rejects malformed schedules before export")
    func invalidSchedule() {
        let medicine = SharedMedicine(
            id: UUID(),
            name: "Invalid",
            amount: 1,
            unitRawValue: MedicineUnit.tablet.rawValue,
            asNeeded: false,
            daysOfWeek: [],
            times: [],
            intervalMinutes: nil,
            intervalLinked: false,
            startDate: CalendarDay(.now),
            endDate: nil,
            notes: nil,
            dailyCap: nil,
            quantityRemaining: nil,
            refillAt: nil,
            packageExpiryDate: nil,
            planID: nil,
            refillScripts: []
        )
        let package = CareSharePackage(
            medicines: [medicine],
            treatmentPlans: []
        )

        #expect(throws: CareShareError.self) {
            try CareShareCodec.encode(package)
        }
    }

    @Test("Care snapshot rejects linked intervals that do not match times")
    func invalidLinkedInterval() {
        let medicine = SharedMedicine(
            id: UUID(),
            name: "Invalid interval",
            amount: 1,
            unitRawValue: MedicineUnit.tablet.rawValue,
            asNeeded: false,
            daysOfWeek: Array(1...7),
            times: [0, 720],
            intervalMinutes: 480,
            intervalLinked: true,
            startDate: CalendarDay(.now),
            endDate: nil,
            notes: nil,
            dailyCap: nil,
            quantityRemaining: nil,
            refillAt: nil,
            packageExpiryDate: nil,
            planID: nil,
            refillScripts: []
        )
        let package = CareSharePackage(
            medicines: [medicine],
            treatmentPlans: []
        )

        #expect(throws: CareShareError.self) {
            try CareShareCodec.encode(package)
        }
    }

    @Test("Care snapshot rejects an oversized file before decoding")
    func oversizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("medcare")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0, count: CareShareCodec.maximumArchiveSize + 1)
            .write(to: url)

        #expect(throws: CareShareError.self) {
            try CareShareCodec.decode(contentsOf: url)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Medicine.self,
            TreatmentPlan.self,
            DoseEvent.self,
            RefillScript.self,
            configurations: configuration
        )
    }
}
