import Foundation
import SwiftData

/// Restore uses merge-by-id: records with an existing UUID are updated in place,
/// and new UUIDs are inserted. The archive is opened and parsed before any
/// SwiftData mutation so a failed parse cannot wipe existing medicines.
enum BackupRestoreService {
    static let fileExtension = "medicationbackup"
    static let currentSchemaVersion = 1

    @MainActor
    static func exportArchive(
        context: ModelContext
    ) throws -> Data {
        let medicines = try context.fetch(FetchDescriptor<Medicine>())
        let plans = try context.fetch(FetchDescriptor<TreatmentPlan>())
        let doses = try context.fetch(FetchDescriptor<DoseEvent>())
        let scripts = try context.fetch(FetchDescriptor<RefillScript>())

        let manifest = BackupManifest(
            schemaVersion: currentSchemaVersion,
            exportedAt: .now,
            medicines: medicines.map(BackupMedicine.init),
            treatmentPlans: plans.map(BackupTreatmentPlan.init),
            doseEvents: doses.map(BackupDoseEvent.init),
            refillScripts: scripts.map(BackupRefillScript.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)

        var zip = StoredZipArchive()
        zip.addFile(path: "manifest.json", data: manifestData)

        for medicine in medicines {
            guard let data = medicine.scannedImageData else { continue }
            zip.addFile(path: "images/\(medicine.id.uuidString).jpg", data: data)
        }

        return zip.finalize()
    }

    @MainActor
    static func importArchive(
        _ data: Data,
        context: ModelContext
    ) throws {
        let files = try StoredZipArchive.unpack(data)
        guard let manifestData = files["manifest.json"] else {
            throw BackupRestoreError.invalidArchive
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: manifestData)
        guard manifest.schemaVersion == currentSchemaVersion else {
            throw BackupRestoreError.unsupportedVersion
        }

        try merge(manifest, images: files, context: context)
    }

    @MainActor
    private static func merge(
        _ manifest: BackupManifest,
        images: [String: Data],
        context: ModelContext
    ) throws {
        let existingMedicines = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Medicine>()).map { ($0.id, $0) }
        )
        let existingPlans = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<TreatmentPlan>()).map { ($0.id, $0) }
        )
        let existingDoses = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<DoseEvent>()).map { ($0.id, $0) }
        )
        let existingScripts = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<RefillScript>()).map { ($0.id, $0) }
        )

        var plansByID = existingPlans
        for record in manifest.treatmentPlans {
            if let plan = plansByID[record.id] {
                plan.title = record.title
                plan.prescriber = record.prescriber
                plan.status = TreatmentPlanStatus(rawValue: record.statusRawValue) ?? plan.status
                plan.completedAt = record.completedAt
                plan.startDate = record.startDate?.date()
                plan.endDate = record.endDate?.date()
            } else {
                let plan = TreatmentPlan(
                    id: record.id,
                    title: record.title,
                    prescriber: record.prescriber,
                    status: TreatmentPlanStatus(rawValue: record.statusRawValue) ?? .active
                )
                plan.completedAt = record.completedAt
                plan.startDate = record.startDate?.date()
                plan.endDate = record.endDate?.date()
                context.insert(plan)
                plansByID[record.id] = plan
            }
        }

        var medicinesByID = existingMedicines
        for record in manifest.medicines {
            guard let unit = MedicineUnit(rawValue: record.unitRawValue) else {
                throw BackupRestoreError.invalidRecord
            }
            let plan = record.planID.flatMap { plansByID[$0] }
            let imageData = imageData(for: record, images: images)
            if let medicine = medicinesByID[record.id] {
                medicine.name = record.name
                medicine.amount = record.amount
                medicine.unit = unit
                medicine.asNeeded = record.asNeeded
                medicine.daysOfWeek = record.daysOfWeek
                medicine.times = record.times
                medicine.intervalMinutes = record.intervalMinutes
                medicine.intervalLinked = record.intervalLinked
                medicine.startDate = record.startDate.date() ?? medicine.startDate
                medicine.endDate = record.endDate?.date()
                medicine.remindersOn = record.remindersOn
                medicine.notes = record.notes
                medicine.packageExpiryDate = record.packageExpiryDate?.date()
                medicine.dailyCap = record.dailyCap
                medicine.quantityRemaining = record.quantityRemaining
                medicine.refillAt = record.refillAt
                medicine.lowStockNotificationSent = record.lowStockNotificationSent
                medicine.status = MedicineStatus(rawValue: record.statusRawValue) ?? medicine.status
                medicine.completedAt = record.completedAt
                medicine.scannedImageData = imageData
                medicine.plan = plan
            } else {
                let medicine = Medicine(
                    id: record.id,
                    name: record.name,
                    amount: record.amount,
                    unit: unit,
                    asNeeded: record.asNeeded,
                    daysOfWeek: record.daysOfWeek,
                    times: record.times,
                    intervalMinutes: record.intervalMinutes,
                    intervalLinked: record.intervalLinked,
                    startDate: record.startDate.date() ?? .now,
                    endDate: record.endDate?.date(),
                    remindersOn: record.remindersOn,
                    notes: record.notes,
                    scannedImageData: imageData,
                    packageExpiryDate: record.packageExpiryDate?.date(),
                    dailyCap: record.dailyCap,
                    quantityRemaining: record.quantityRemaining,
                    refillAt: record.refillAt,
                    status: MedicineStatus(rawValue: record.statusRawValue) ?? .active,
                    plan: plan
                )
                medicine.lowStockNotificationSent = record.lowStockNotificationSent
                medicine.completedAt = record.completedAt
                context.insert(medicine)
                medicinesByID[record.id] = medicine
            }
        }

        for record in manifest.doseEvents {
            guard let medicine = medicinesByID[record.medicineID] else {
                throw BackupRestoreError.invalidRecord
            }
            if let event = existingDoses[record.id] {
                event.scheduledAt = record.scheduledAt
                event.takenAt = record.takenAt
                event.outcome = DoseOutcome(rawValue: record.outcomeRawValue) ?? event.outcome
                event.medicine = medicine
            } else {
                let event = DoseEvent(
                    id: record.id,
                    medicine: medicine,
                    scheduledAt: record.scheduledAt,
                    takenAt: record.takenAt,
                    outcome: DoseOutcome(rawValue: record.outcomeRawValue) ?? .taken
                )
                context.insert(event)
            }
        }

        for record in manifest.refillScripts {
            let medicine = record.medicineID.flatMap { medicinesByID[$0] }
            if let script = existingScripts[record.id] {
                script.scriptNumber = record.scriptNumber
                script.issuedDate = record.issuedDate?.date()
                script.expiryDate = record.expiryDate?.date()
                script.repeatsAuthorised = record.repeatsAuthorised
                script.repeatsRemaining = record.repeatsRemaining
                script.prescriber = record.prescriber
                script.lastReviewedAt = record.lastReviewedAt
                script.notes = record.notes
                script.medicine = medicine
            } else {
                let script = RefillScript(
                    id: record.id,
                    medicine: medicine,
                    scriptNumber: record.scriptNumber,
                    issuedDate: record.issuedDate?.date(),
                    expiryDate: record.expiryDate?.date(),
                    repeatsAuthorised: record.repeatsAuthorised,
                    repeatsRemaining: record.repeatsRemaining,
                    prescriber: record.prescriber,
                    lastReviewedAt: record.lastReviewedAt,
                    notes: record.notes
                )
                context.insert(script)
            }
        }

        try context.save()
    }

    private static func imageData(
        for record: BackupMedicine,
        images: [String: Data]
    ) -> Data? {
        if let data = images["images/\(record.id.uuidString).jpg"] {
            return data
        }
        if let encoded = record.scannedImageDataBase64,
           let data = Data(base64Encoded: encoded) {
            return data
        }
        return nil
    }
}

enum BackupRestoreError: LocalizedError {
    case invalidArchive
    case unsupportedVersion
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            "This backup file could not be read."
        case .unsupportedVersion:
            "This backup was created by an unsupported app version."
        case .invalidRecord:
            "This backup contains invalid medication data."
        }
    }
}
