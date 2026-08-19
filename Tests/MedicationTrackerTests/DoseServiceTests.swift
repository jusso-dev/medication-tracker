import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@MainActor
@Suite("Dose logging")
struct DoseServiceTests {
    @Test("Daily cap blocks additional as-needed doses")
    func dailyCap() throws {
        let (container, medicine) = try makeMedicine(
            amount: 1,
            unit: .tablet,
            dailyCap: 2
        )
        let context = container.mainContext

        try DoseService.record(
            medicine: medicine,
            outcome: .loggedAsNeeded,
            context: context
        )
        #expect(DoseService.canLogAsNeeded(medicine: medicine))

        try DoseService.record(
            medicine: medicine,
            outcome: .loggedAsNeeded,
            context: context
        )
        #expect(!DoseService.canLogAsNeeded(medicine: medicine))
    }

    @Test("Tablet doses subtract the dose amount and signal refill once")
    func inventoryAndRefill() throws {
        let (container, medicine) = try makeMedicine(
            amount: 2,
            unit: .tablet,
            quantity: 10,
            refillAt: 5
        )
        let context = container.mainContext

        let first = try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            context: context
        )
        let second = try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            context: context
        )
        let third = try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            context: context
        )
        medicine.lowStockNotificationSent = true
        let fourth = try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            context: context
        )

        #expect(!first)
        #expect(!second)
        #expect(third)
        #expect(!fourth)
        #expect(medicine.quantityRemaining == 2)
    }

    @Test("A scheduled dose cannot be recorded twice")
    func scheduledDoseIsIdempotent() throws {
        let (container, medicine) = try makeMedicine(
            amount: 1,
            unit: .tablet,
            quantity: 10
        )
        let context = container.mainContext
        let scheduledAt = Date.now

        try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            scheduledAt: scheduledAt,
            context: context
        )
        try DoseService.record(
            medicine: medicine,
            outcome: .taken,
            scheduledAt: scheduledAt,
            context: context
        )

        #expect(medicine.doseEvents.count == 1)
        #expect(medicine.quantityRemaining == 9)
    }

    private func makeMedicine(
        amount: Decimal,
        unit: MedicineUnit,
        dailyCap: Int? = nil,
        quantity: Decimal? = nil,
        refillAt: Decimal? = nil
    ) throws -> (ModelContainer, Medicine) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Medicine.self,
            TreatmentPlan.self,
            DoseEvent.self,
            RefillScript.self,
            configurations: configuration
        )
        let medicine = Medicine(
            name: "Test medicine",
            amount: amount,
            unit: unit,
            asNeeded: true,
            startDate: .now,
            dailyCap: dailyCap,
            quantityRemaining: quantity,
            refillAt: refillAt
        )
        container.mainContext.insert(medicine)
        try container.mainContext.save()
        return (container, medicine)
    }
}
