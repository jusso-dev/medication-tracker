import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MedicationBackup: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let createdAt: Date
    let treatmentPlans: [MedicationBackupPlan]
    let medicines: [MedicationBackupMedicine]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        createdAt: Date = .now,
        treatmentPlans: [MedicationBackupPlan],
        medicines: [MedicationBackupMedicine]
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.treatmentPlans = treatmentPlans
        self.medicines = medicines
    }
}

struct MedicationBackupPlan: Codable, Sendable {
    let id: UUID
    let title: String
    let prescriber: String?
    let startDate: CalendarDay?
    let endDate: CalendarDay?
    let statusRawValue: String
    let completedAt: Date?
}

struct MedicationBackupMedicine: Codable, Sendable {
    let id: UUID
    let name: String
    let amount: Decimal
    let unitRawValue: String
    let asNeeded: Bool
    let daysOfWeek: [Int]
    let times: [Int]
    let intervalMinutes: Int?
    let intervalLinked: Bool
    let startDate: CalendarDay
    let endDate: CalendarDay?
    let remindersOn: Bool
    let notes: String?
    let scannedImageData: Data?
    let packageExpiryDate: CalendarDay?
    let dailyCap: Int?
    let quantityRemaining: Decimal?
    let refillAt: Decimal?
    let lowStockNotificationSent: Bool
    let statusRawValue: String
    let completedAt: Date?
    let planID: UUID?
    let doseEvents: [MedicationBackupDoseEvent]
    let refillScripts: [MedicationBackupRefillScript]
}

struct MedicationBackupDoseEvent: Codable, Sendable {
    let id: UUID
    let scheduledAt: Date?
    let takenAt: Date?
    let outcomeRawValue: String
}

struct MedicationBackupRefillScript: Codable, Sendable {
    let id: UUID
    let scriptNumber: String?
    let issuedDate: CalendarDay?
    let expiryDate: CalendarDay?
    let repeatsAuthorised: Int?
    let repeatsRemaining: Int
    let prescriber: String?
    let lastReviewedAt: Date?
    let notes: String?
}

enum MedicationBackupCodec {
    static let maximumArchiveSize = 100_000_000
    static let maximumImageSize = 8_000_000

    static func encode(_ backup: MedicationBackup) throws -> Data {
        try validate(backup)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(backup)
        guard data.count <= maximumArchiveSize else {
            throw MedicationBackupError.archiveTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> MedicationBackup {
        guard data.count <= maximumArchiveSize else {
            throw MedicationBackupError.archiveTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(MedicationBackup.self, from: data)
        try validate(backup)
        return backup
    }

    static func decode(contentsOf url: URL) throws -> MedicationBackup {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber,
           size.intValue > maximumArchiveSize {
            throw MedicationBackupError.archiveTooLarge
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumArchiveSize + 1) ?? Data()
        return try decode(data)
    }

    static func validate(_ backup: MedicationBackup) throws {
        guard backup.schemaVersion == MedicationBackup.currentSchemaVersion else {
            throw MedicationBackupError.unsupportedVersion
        }
        let events = backup.medicines.flatMap(\.doseEvents)
        let scripts = backup.medicines.flatMap(\.refillScripts)
        guard backup.medicines.count <= 1_000,
              backup.treatmentPlans.count <= 500,
              events.count <= 50_000,
              scripts.count <= 10_000,
              Set(backup.medicines.map(\.id)).count == backup.medicines.count,
              Set(backup.treatmentPlans.map(\.id)).count == backup.treatmentPlans.count,
              Set(events.map(\.id)).count == events.count,
              Set(scripts.map(\.id)).count == scripts.count else {
            throw MedicationBackupError.invalidArchive
        }

        let planIDs = Set(backup.treatmentPlans.map(\.id))
        for plan in backup.treatmentPlans {
            guard plan.title.nilIfBlank != nil,
                  plan.title.count <= 120,
                  (plan.prescriber?.count ?? 0) <= 120,
                  TreatmentPlanStatus(rawValue: plan.statusRawValue) != nil,
                  plan.startDate?.date() != nil || plan.startDate == nil,
                  plan.endDate?.date() != nil || plan.endDate == nil else {
                throw MedicationBackupError.invalidArchive
            }
        }

        for medicine in backup.medicines {
            guard let unit = MedicineUnit(rawValue: medicine.unitRawValue),
                  MedicineStatus(rawValue: medicine.statusRawValue) != nil,
                  medicine.name.nilIfBlank != nil,
                  medicine.name.count <= 120,
                  medicine.amount > 0,
                  medicine.amount <= 1_000_000_000,
                  medicine.startDate.date() != nil,
                  medicine.endDate?.date() != nil || medicine.endDate == nil,
                  medicine.packageExpiryDate?.date() != nil
                    || medicine.packageExpiryDate == nil,
                  medicine.daysOfWeek.count <= 7,
                  medicine.times.count <= 48,
                  Set(medicine.daysOfWeek).count == medicine.daysOfWeek.count,
                  Set(medicine.times).count == medicine.times.count,
                  medicine.daysOfWeek.allSatisfy({ (1...7).contains($0) }),
                  medicine.times.allSatisfy({ (0..<1_440).contains($0) }),
                  medicine.asNeeded
                    ? medicine.daysOfWeek.isEmpty && medicine.times.isEmpty
                    : !medicine.daysOfWeek.isEmpty && !medicine.times.isEmpty,
                  intervalMetadataIsValid(for: medicine),
                  (medicine.notes?.count ?? 0) <= 2_000,
                  (medicine.scannedImageData?.count ?? 0) <= maximumImageSize,
                  medicine.dailyCap.map({ $0 > 0 }) ?? true,
                  medicine.quantityRemaining.map({ $0 >= 0 }) ?? true,
                  medicine.refillAt.map({ $0 >= 0 }) ?? true,
                  medicine.refillAt == nil || medicine.quantityRemaining != nil,
                  medicine.planID.map(planIDs.contains) ?? true,
                  unit != .other || !medicine.unitRawValue.isEmpty else {
                throw MedicationBackupError.invalidArchive
            }
            for event in medicine.doseEvents {
                guard DoseOutcome(rawValue: event.outcomeRawValue) != nil else {
                    throw MedicationBackupError.invalidArchive
                }
            }
            for script in medicine.refillScripts {
                guard script.issuedDate?.date() != nil || script.issuedDate == nil,
                      script.expiryDate?.date() != nil || script.expiryDate == nil,
                      script.repeatsRemaining >= 0,
                      script.repeatsAuthorised.map({ $0 >= script.repeatsRemaining }) ?? true,
                      (script.scriptNumber?.count ?? 0) <= 120,
                      (script.prescriber?.count ?? 0) <= 120,
                      (script.notes?.count ?? 0) <= 2_000 else {
                    throw MedicationBackupError.invalidArchive
                }
            }
        }
    }

    private static func intervalMetadataIsValid(
        for medicine: MedicationBackupMedicine
    ) -> Bool {
        if medicine.asNeeded {
            return medicine.intervalMinutes == nil && !medicine.intervalLinked
        }
        guard medicine.intervalLinked else {
            return medicine.intervalMinutes == nil
        }
        guard let interval = medicine.intervalMinutes,
              (1...1_440).contains(interval),
              medicine.times.count >= 2 else {
            return false
        }
        let sorted = medicine.times.sorted()
        for index in sorted.indices {
            let next = sorted.index(after: index) < sorted.endIndex
                ? sorted[sorted.index(after: index)]
                : sorted[0] + 1_440
            if next - sorted[index] != interval {
                return false
            }
        }
        return true
    }
}

@MainActor
enum MedicationBackupService {
    static func makeBackup(context: ModelContext) throws -> MedicationBackup {
        let medicines = try context.fetch(FetchDescriptor<Medicine>())
        let plans = try context.fetch(FetchDescriptor<TreatmentPlan>())
        let backupPlans = plans.map(makeBackupPlan)
        let backupMedicines = medicines.map(makeBackupMedicine)
        return MedicationBackup(
            treatmentPlans: backupPlans,
            medicines: backupMedicines
        )
    }

    private static func makeBackupPlan(_ plan: TreatmentPlan) -> MedicationBackupPlan {
        MedicationBackupPlan(
            id: plan.id,
            title: plan.title,
            prescriber: plan.prescriber,
            startDate: plan.startDate.map { CalendarDay($0) },
            endDate: plan.endDate.map { CalendarDay($0) },
            statusRawValue: plan.statusRawValue,
            completedAt: plan.completedAt
        )
    }

    private static func makeBackupMedicine(
        _ medicine: Medicine
    ) -> MedicationBackupMedicine {
        MedicationBackupMedicine(
            id: medicine.id,
            name: medicine.name,
            amount: medicine.amount,
            unitRawValue: medicine.unitRawValue,
            asNeeded: medicine.asNeeded,
            daysOfWeek: medicine.daysOfWeek,
            times: medicine.times,
            intervalMinutes: medicine.intervalMinutes,
            intervalLinked: medicine.intervalLinked,
            startDate: CalendarDay(medicine.startDate),
            endDate: medicine.endDate.map { CalendarDay($0) },
            remindersOn: medicine.remindersOn,
            notes: medicine.notes,
            scannedImageData: medicine.scannedImageData,
            packageExpiryDate: medicine.packageExpiryDate.map { CalendarDay($0) },
            dailyCap: medicine.dailyCap,
            quantityRemaining: medicine.quantityRemaining,
            refillAt: medicine.refillAt,
            lowStockNotificationSent: medicine.lowStockNotificationSent,
            statusRawValue: medicine.statusRawValue,
            completedAt: medicine.completedAt,
            planID: medicine.plan?.id,
            doseEvents: medicine.doseEvents.map(makeBackupDoseEvent),
            refillScripts: medicine.refillScripts.map(makeBackupRefillScript)
        )
    }

    private static func makeBackupDoseEvent(
        _ event: DoseEvent
    ) -> MedicationBackupDoseEvent {
        MedicationBackupDoseEvent(
            id: event.id,
            scheduledAt: event.scheduledAt,
            takenAt: event.takenAt,
            outcomeRawValue: event.outcomeRawValue
        )
    }

    private static func makeBackupRefillScript(
        _ script: RefillScript
    ) -> MedicationBackupRefillScript {
        MedicationBackupRefillScript(
            id: script.id,
            scriptNumber: script.scriptNumber,
            issuedDate: script.issuedDate.map { CalendarDay($0) },
            expiryDate: script.expiryDate.map { CalendarDay($0) },
            repeatsAuthorised: script.repeatsAuthorised,
            repeatsRemaining: script.repeatsRemaining,
            prescriber: script.prescriber,
            lastReviewedAt: script.lastReviewedAt,
            notes: script.notes
        )
    }

    static func restore(_ backup: MedicationBackup, context: ModelContext) throws {
        try MedicationBackupCodec.validate(backup)
        let existingMedicines = try context.fetch(FetchDescriptor<Medicine>())
        let existingPlans = try context.fetch(FetchDescriptor<TreatmentPlan>())

        do {
            try context.transaction {
                for medicine in existingMedicines {
                    context.delete(medicine)
                }
                for plan in existingPlans {
                    context.delete(plan)
                }
                try context.save()

                var plansByID: [UUID: TreatmentPlan] = [:]
                for source in backup.treatmentPlans {
                    guard let status = TreatmentPlanStatus(rawValue: source.statusRawValue) else {
                        throw MedicationBackupError.invalidArchive
                    }
                    let plan = TreatmentPlan(
                        id: source.id,
                        title: source.title,
                        prescriber: source.prescriber,
                        status: status
                    )
                    plan.completedAt = source.completedAt
                    context.insert(plan)
                    plansByID[source.id] = plan
                }

                for source in backup.medicines {
                    guard let unit = MedicineUnit(rawValue: source.unitRawValue),
                          let status = MedicineStatus(rawValue: source.statusRawValue),
                          let startDate = source.startDate.date() else {
                        throw MedicationBackupError.invalidArchive
                    }
                    let medicine = Medicine(
                        id: source.id,
                        name: source.name,
                        amount: source.amount,
                        unit: unit,
                        asNeeded: source.asNeeded,
                        daysOfWeek: source.daysOfWeek,
                        times: source.times,
                        intervalMinutes: source.intervalMinutes,
                        intervalLinked: source.intervalLinked,
                        startDate: startDate,
                        endDate: source.endDate?.date(),
                        remindersOn: source.remindersOn,
                        notes: source.notes,
                        scannedImageData: source.scannedImageData,
                        packageExpiryDate: source.packageExpiryDate?.date(),
                        dailyCap: source.dailyCap,
                        quantityRemaining: source.quantityRemaining,
                        refillAt: source.refillAt,
                        status: status,
                        plan: source.planID.flatMap { plansByID[$0] }
                    )
                    medicine.lowStockNotificationSent = source.lowStockNotificationSent
                    medicine.completedAt = source.completedAt
                    context.insert(medicine)

                    for event in source.doseEvents {
                        guard let outcome = DoseOutcome(rawValue: event.outcomeRawValue) else {
                            throw MedicationBackupError.invalidArchive
                        }
                        context.insert(DoseEvent(
                            id: event.id,
                            medicine: medicine,
                            scheduledAt: event.scheduledAt,
                            takenAt: event.takenAt,
                            outcome: outcome
                        ))
                    }
                    for script in source.refillScripts {
                        context.insert(RefillScript(
                            id: script.id,
                            medicine: medicine,
                            scriptNumber: script.scriptNumber,
                            issuedDate: script.issuedDate?.date(),
                            expiryDate: script.expiryDate?.date(),
                            repeatsAuthorised: script.repeatsAuthorised,
                            repeatsRemaining: script.repeatsRemaining,
                            prescriber: script.prescriber,
                            lastReviewedAt: script.lastReviewedAt,
                            notes: script.notes
                        ))
                    }
                }

                for source in backup.treatmentPlans {
                    let plan = plansByID[source.id]
                    plan?.startDate = source.startDate?.date()
                    plan?.endDate = source.endDate?.date()
                }
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }
}

struct MedicationBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.medicationBackup] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= MedicationBackupCodec.maximumArchiveSize else {
            throw MedicationBackupError.archiveTooLarge
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let medicationBackup = UTType(
        exportedAs: "dev.jusso.medicationtracker.backup",
        conformingTo: .json
    )
}

enum MedicationBackupError: LocalizedError {
    case archiveTooLarge
    case unsupportedVersion
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .archiveTooLarge:
            "This backup is too large to open safely."
        case .unsupportedVersion:
            "This backup was created by an unsupported app version."
        case .invalidArchive:
            "This file is not a valid Medication Tracker backup."
        }
    }
}
