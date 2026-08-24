import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@MainActor
@Suite("Medication backups")
struct MedicationBackupTests {
    @Test("Full backup round-trip replaces and restores every record type")
    func fullRoundTrip() throws {
        let source = try MedicationDataStore.makeContainer(
            isStoredInMemoryOnly: true
        )
        let plan = TreatmentPlan(title: "Pain plan", prescriber: "Dr Chen")
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let medicine = Medicine(
            name: "Prednisolone",
            amount: Decimal(string: "12.5")!,
            unit: .mg,
            asNeeded: false,
            daysOfWeek: [2, 4, 6],
            times: [480],
            startDate: .now,
            endDate: nil,
            remindersOn: true,
            notes: "With food",
            scannedImageData: imageData,
            quantityRemaining: 20,
            refillAt: 5,
            plan: plan
        )
        let event = DoseEvent(
            medicine: medicine,
            scheduledAt: .now,
            takenAt: .now,
            outcome: .taken
        )
        let script = RefillScript(
            medicine: medicine,
            scriptNumber: "RX-42",
            repeatsAuthorised: 3,
            repeatsRemaining: 2
        )
        source.mainContext.insert(plan)
        source.mainContext.insert(medicine)
        source.mainContext.insert(event)
        source.mainContext.insert(script)
        try source.mainContext.save()

        let backup = try MedicationBackupService.makeBackup(
            context: source.mainContext
        )
        let encoded = try MedicationBackupCodec.encode(backup)
        let decoded = try MedicationBackupCodec.decode(encoded)

        let destination = try MedicationDataStore.makeContainer(
            isStoredInMemoryOnly: true
        )
        destination.mainContext.insert(Medicine(
            name: "Replace me",
            amount: 1,
            unit: .tablet,
            asNeeded: true,
            startDate: .now
        ))
        try destination.mainContext.save()

        try MedicationBackupService.restore(
            decoded,
            context: destination.mainContext
        )

        let medicines = try destination.mainContext.fetch(
            FetchDescriptor<Medicine>()
        )
        let restored = try #require(medicines.first)
        #expect(medicines.count == 1)
        #expect(restored.name == "Prednisolone")
        #expect(restored.amount == Decimal(string: "12.5"))
        #expect(restored.endDate == nil)
        #expect(restored.scannedImageData == imageData)
        #expect(restored.plan?.title == "Pain plan")
        #expect(restored.doseEvents.count == 1)
        #expect(restored.doseEvents.first?.outcome == .taken)
        #expect(restored.refillScripts.first?.scriptNumber == "RX-42")
    }

    @Test("Unsupported backup version is rejected before restore")
    func unsupportedVersion() {
        let backup = MedicationBackup(
            schemaVersion: 999,
            treatmentPlans: [],
            medicines: []
        )

        #expect(throws: MedicationBackupError.self) {
            try MedicationBackupCodec.encode(backup)
        }
    }
}
