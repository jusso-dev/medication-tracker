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

@MainActor
@Suite("Local data store")
struct MedicationDataStoreTests {
    @Test("Saved medicines survive reopening the on-device store")
    func savedMedicinesSurviveReopening() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("MedicationTracker.store")
        let medicineID = UUID()

        do {
            let configuration = ModelConfiguration(url: storeURL)
            let container = try MedicationDataStore.makeContainer(
                configuration: configuration
            )
            let medicine = Medicine(
                id: medicineID,
                name: "Persistent medicine",
                amount: 1,
                unit: .tablet,
                asNeeded: true,
                startDate: .now
            )
            container.mainContext.insert(medicine)
            try container.mainContext.save()
        }

        let configuration = ModelConfiguration(url: storeURL)
        let reopenedContainer = try MedicationDataStore.makeContainer(
            configuration: configuration
        )
        let medicines = try reopenedContainer.mainContext.fetch(FetchDescriptor<Medicine>())

        #expect(medicines.contains { $0.id == medicineID })
    }

    @Test("Scanned medicine details persist after reopening the store")
    func scannedMedicineSurvivesReopening() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("MedicationTracker.store")
        let scannedImageData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let scan = MedicationOCRService.parse(lines: [
            "AMOXICILLIN 500 mg",
            "EXP 08/2027"
        ], scannedImageData: scannedImageData)

        do {
            let container = try MedicationDataStore.makeContainer(
                configuration: ModelConfiguration(url: storeURL)
            )
            let draft = MedicineDraft()
            draft.applyScan(scan)
            draft.setOngoing()
            _ = try draft.save(context: container.mainContext)
        }

        let reopenedContainer = try MedicationDataStore.makeContainer(
            configuration: ModelConfiguration(url: storeURL)
        )
        let medicines = try reopenedContainer.mainContext.fetch(FetchDescriptor<Medicine>())
        let medicine = try #require(medicines.first)

        #expect(medicine.name == "Amoxicillin")
        #expect(medicine.amount == 500)
        #expect(medicine.unit == .mg)
        #expect(medicine.packageExpiryDate != nil)
        #expect(medicine.scannedImageData == scannedImageData)
    }
}
