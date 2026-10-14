import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@MainActor
@Suite("Scan image persistence")
struct ScanImagePersistenceTests {
    @Test("applyScan and save keep image bytes on scannedImageData")
    func applyScanKeepsImageBytes() throws {
        let container = try makeContainer()
        let image = Data("scan-bytes".utf8)
        let result = MedicationOCRService.parse(
            lines: [
                "AMOXICILLIN 500 mg",
                "EXP 08/2027"
            ],
            scannedImageData: image
        )

        let draft = MedicineDraft()
        draft.applyScan(result)
        draft.setOngoing()
        let medicine = try draft.save(context: container.mainContext)

        #expect(medicine.scannedImageData == image)

        let edited = MedicineDraft(medicine: medicine)
        #expect(edited.scannedImageData == image)
        _ = try edited.save(context: container.mainContext)
        #expect(medicine.scannedImageData == image)
    }
}

@MainActor
@Suite("Backup and restore")
struct BackupRestoreTests {
    @Test("export and import merge by id and keep scan images")
    func mergeByID() throws {
        let source = try makeContainer()
        let medicineID = UUID()
        let medicine = Medicine(
            id: medicineID,
            name: "Amoxicillin",
            amount: 500,
            unit: .mg,
            asNeeded: true,
            startDate: .now,
            notes: "Original",
            scannedImageData: Data("page".utf8)
        )
        source.mainContext.insert(medicine)
        try source.mainContext.save()

        let archive = try BackupRestoreService.exportArchive(
            context: source.mainContext
        )

        let destination = try makeContainer()
        let existing = Medicine(
            id: medicineID,
            name: "Placeholder",
            amount: 1,
            unit: .tablet,
            asNeeded: true,
            startDate: .now,
            notes: "Should be replaced"
        )
        let extra = Medicine(
            id: UUID(),
            name: "Keep me",
            amount: 1,
            unit: .tablet,
            asNeeded: true,
            startDate: .now
        )
        destination.mainContext.insert(existing)
        destination.mainContext.insert(extra)
        try destination.mainContext.save()

        try BackupRestoreService.importArchive(
            archive,
            context: destination.mainContext
        )

        let medicines = try destination.mainContext.fetch(FetchDescriptor<Medicine>())
        let merged = try #require(medicines.first { $0.id == medicineID })
        #expect(merged.name == "Amoxicillin")
        #expect(merged.notes == "Original")
        #expect(medicines.contains { $0.name == "Keep me" })
        #expect(merged.scannedImageData == Data("page".utf8))
    }

    @Test("failed parse does not delete existing medicines")
    func failedParseLeavesData() throws {
        let container = try makeContainer()
        let medicine = Medicine(
            name: "Keep this",
            amount: 1,
            unit: .tablet,
            asNeeded: true,
            startDate: .now
        )
        container.mainContext.insert(medicine)
        try container.mainContext.save()

        #expect(throws: BackupRestoreError.self) {
            try BackupRestoreService.importArchive(
                Data("not-a-backup".utf8),
                context: container.mainContext
            )
        }

        let remaining = try container.mainContext.fetch(FetchDescriptor<Medicine>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Keep this")
    }
}

@MainActor
@Suite("Scheduled times")
struct ScheduledTimeTests {
    @Test("updateTime keeps the same ScheduledTime id when minutes change")
    func updateTimeKeepsIdentity() {
        let draft = MedicineDraft()
        draft.scheduledTimes = [ScheduledTime(minutes: 480)]
        let originalID = draft.scheduledTimes[0].id

        #expect(draft.updateTime(id: originalID, to: 495))
        #expect(draft.scheduledTimes.count == 1)
        #expect(draft.scheduledTimes[0].id == originalID)
        #expect(draft.scheduledTimes[0].minutes == 495)
        #expect(draft.times == [495])
    }
}

@MainActor
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
