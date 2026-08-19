import Foundation
import SwiftData

enum CareShareCodec {
    static let maximumArchiveSize = 5_000_000

    static func encode(_ package: CareSharePackage) throws -> Data {
        try validate(package)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(package)
        guard data.count <= maximumArchiveSize else {
            throw CareShareError.archiveTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> CareSharePackage {
        guard data.count <= maximumArchiveSize else {
            throw CareShareError.archiveTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(CareSharePackage.self, from: data)
        try validate(package)
        return package
    }

    static func decode(contentsOf url: URL) throws -> CareSharePackage {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber,
           size.intValue > maximumArchiveSize {
            throw CareShareError.archiveTooLarge
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumArchiveSize + 1) ?? Data()
        guard data.count <= maximumArchiveSize else {
            throw CareShareError.archiveTooLarge
        }
        return try decode(data)
    }

    static func validate(_ package: CareSharePackage) throws {
        guard package.schemaVersion == CareSharePackage.currentSchemaVersion else {
            throw CareShareError.unsupportedVersion
        }
        guard package.medicines.count <= 250,
              package.treatmentPlans.count <= 100,
              package.medicines.flatMap(\.refillScripts).count <= 1_000,
              Set(package.medicines.map(\.id)).count == package.medicines.count,
              Set(package.treatmentPlans.map(\.id)).count == package.treatmentPlans.count,
              Set(package.medicines.flatMap(\.refillScripts).map(\.id)).count
                == package.medicines.flatMap(\.refillScripts).count else {
            throw CareShareError.tooManyRecords
        }

        let planIDs = Set(package.treatmentPlans.map(\.id))
        for plan in package.treatmentPlans {
            guard plan.title.nilIfBlank != nil,
                  plan.title.count <= 120,
                  (plan.prescriber?.count ?? 0) <= 120 else {
                throw CareShareError.invalidMedicine
            }
        }

        for medicine in package.medicines {
            guard let startDate = medicine.startDate.date() else {
                throw CareShareError.invalidMedicine
            }
            let endDate = medicine.endDate?.date()
            guard medicine.endDate == nil || endDate != nil,
                  medicine.packageExpiryDate == nil
                    || medicine.packageExpiryDate?.date() != nil else {
                throw CareShareError.invalidMedicine
            }
            guard let unit = MedicineUnit(rawValue: medicine.unitRawValue),
                  medicine.amount > 0,
                  medicine.amount <= 1_000_000_000,
                  medicine.name.nilIfBlank != nil,
                  medicine.name.count <= 120,
                  medicine.daysOfWeek.count <= 7,
                  medicine.times.count <= 48,
                  Set(medicine.daysOfWeek).count == medicine.daysOfWeek.count,
                  Set(medicine.times).count == medicine.times.count,
                  medicine.daysOfWeek.allSatisfy({ (1...7).contains($0) }),
                  medicine.times.allSatisfy({ (0..<1_440).contains($0) }),
                  (medicine.asNeeded
                    ? medicine.daysOfWeek.isEmpty && medicine.times.isEmpty
                    : !medicine.daysOfWeek.isEmpty && !medicine.times.isEmpty),
                  intervalMetadataIsValid(for: medicine),
                  (medicine.notes?.count ?? 0) <= 2_000,
                  medicine.dailyCap.map({ $0 > 0 }) ?? true,
                  medicine.quantityRemaining.map({ $0 >= 0 }) ?? true,
                  medicine.refillAt.map({ $0 >= 0 }) ?? true,
                  medicine.refillAt == nil || medicine.quantityRemaining != nil,
                  medicine.refillScripts.count <= 50,
                  endDate.map({ $0.startOfDay >= startDate.startOfDay }) ?? true,
                  medicine.planID.map(planIDs.contains) ?? true,
                  unit != .other || !medicine.unitRawValue.isEmpty else {
                throw CareShareError.invalidMedicine
            }

            for script in medicine.refillScripts {
                guard script.issuedDate == nil || script.issuedDate?.date() != nil,
                      script.expiryDate == nil || script.expiryDate?.date() != nil,
                      script.repeatsRemaining >= 0,
                      script.repeatsAuthorised.map({ $0 >= script.repeatsRemaining }) ?? true,
                      (script.scriptNumber?.count ?? 0) <= 120,
                      (script.prescriber?.count ?? 0) <= 120,
                      (script.notes?.count ?? 0) <= 2_000 else {
                    throw CareShareError.invalidRefillScript
                }
            }
        }
    }

    private static func intervalMetadataIsValid(
        for medicine: SharedMedicine
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

enum CareShareService {
    @MainActor
    static func makePackage(
        medicines: [Medicine],
        treatmentPlans: [TreatmentPlan],
        options: CareShareOptions = CareShareOptions()
    ) -> CareSharePackage {
        let activeMedicines = medicines
            .filter { $0.status == .active }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var sharedMedicines: [SharedMedicine] = []
        for medicine in activeMedicines {
            var scripts: [SharedRefillScript] = []
            if options.includeRefillScripts {
                scripts = medicine.refillScripts.map { script in
                    SharedRefillScript(
                        id: script.id,
                        scriptNumber: script.scriptNumber,
                        issuedDate: script.issuedDate.map {
                            CalendarDay($0)
                        },
                        expiryDate: script.expiryDate.map {
                            CalendarDay($0)
                        },
                        repeatsAuthorised: script.repeatsAuthorised,
                        repeatsRemaining: script.repeatsRemaining,
                        prescriber: options.includePrescriberNames
                            ? script.prescriber
                            : nil,
                        lastReviewedAt: script.lastReviewedAt,
                        notes: options.includeNotes ? script.notes : nil
                    )
                }
            }

            let sharedEndDate = medicine.endDate.map {
                CalendarDay($0)
            }
            let sharedNotes = options.includeNotes ? medicine.notes : nil
            let sharedQuantity = options.includeInventory
                ? medicine.quantityRemaining
                : nil
            let sharedRefillAt = options.includeInventory
                ? medicine.refillAt
                : nil
            let sharedPackageExpiry = medicine.packageExpiryDate.map {
                CalendarDay($0)
            }
            let sharedMedicine = SharedMedicine(
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
                endDate: sharedEndDate,
                notes: sharedNotes,
                dailyCap: medicine.dailyCap,
                quantityRemaining: sharedQuantity,
                refillAt: sharedRefillAt,
                packageExpiryDate: sharedPackageExpiry,
                planID: medicine.plan?.id,
                refillScripts: scripts
            )
            sharedMedicines.append(sharedMedicine)
        }
        let usedPlanIDs = Set(sharedMedicines.compactMap { $0.planID })
        let sharedPlans = treatmentPlans
            .filter { usedPlanIDs.contains($0.id) }
            .map {
                SharedTreatmentPlan(
                    id: $0.id,
                    title: $0.title,
                    prescriber: options.includePrescriberNames
                        ? $0.prescriber
                        : nil
                )
            }
        return CareSharePackage(
            medicines: sharedMedicines,
            treatmentPlans: sharedPlans
        )
    }

    static func importPackage(
        _ package: CareSharePackage,
        context: ModelContext
    ) throws -> CareShareImportSummary {
        try CareShareCodec.validate(package)

        let currentMedicines = try context.fetch(FetchDescriptor<Medicine>())
        let currentPlans = try context.fetch(FetchDescriptor<TreatmentPlan>())
        let currentScripts = try context.fetch(FetchDescriptor<RefillScript>())
        let existingMedicineIDs = Set(currentMedicines.map(\.id))
        var knownScriptIDs = Set(currentScripts.map(\.id))
        let existingPlansByID = Dictionary(
            uniqueKeysWithValues: currentPlans.map { ($0.id, $0) }
        )
        let neededPlanIDs = Set(package.medicines.compactMap { medicine in
            existingMedicineIDs.contains(medicine.id) ? nil : medicine.planID
        })
        var importPlansBySourceID: [UUID: TreatmentPlan] = [:]
        var addedMedicines = 0
        var addedScripts = 0
        var skippedMedicines = 0
        var touchedPlanIDs: Set<UUID> = []

        do {
            try context.transaction {
                for sharedPlan in package.treatmentPlans
                where neededPlanIDs.contains(sharedPlan.id) {
                    if let existing = existingPlansByID[sharedPlan.id],
                       existing.status == .active {
                        importPlansBySourceID[sharedPlan.id] = existing
                    } else {
                        let plan = TreatmentPlan(
                            id: existingPlansByID[sharedPlan.id] == nil
                                ? sharedPlan.id
                                : UUID(),
                            title: sharedPlan.title,
                            prescriber: sharedPlan.prescriber
                        )
                        context.insert(plan)
                        importPlansBySourceID[sharedPlan.id] = plan
                    }
                }

                for shared in package.medicines {
                    if existingMedicineIDs.contains(shared.id) {
                        skippedMedicines += 1
                        continue
                    }
                    guard let unit = MedicineUnit(rawValue: shared.unitRawValue) else {
                        throw CareShareError.invalidMedicine
                    }

                    let medicine = Medicine(
                        id: shared.id,
                        name: shared.name,
                        amount: shared.amount,
                        unit: unit,
                        asNeeded: shared.asNeeded,
                        daysOfWeek: shared.daysOfWeek,
                        times: shared.times,
                        intervalMinutes: shared.intervalMinutes,
                        intervalLinked: shared.intervalLinked,
                        startDate: shared.startDate.date() ?? .now,
                        endDate: shared.endDate?.date(),
                        remindersOn: false,
                        notes: shared.notes,
                        packageExpiryDate: shared.packageExpiryDate?.date(),
                        dailyCap: shared.dailyCap,
                        quantityRemaining: shared.quantityRemaining,
                        refillAt: shared.refillAt,
                        plan: shared.planID.flatMap { importPlansBySourceID[$0] }
                    )
                    context.insert(medicine)
                    addedMedicines += 1
                    if let planID = shared.planID {
                        touchedPlanIDs.insert(planID)
                    }

                    for sharedScript in shared.refillScripts
                    where !knownScriptIDs.contains(sharedScript.id) {
                        let script = RefillScript(
                            id: sharedScript.id,
                            medicine: medicine,
                            scriptNumber: sharedScript.scriptNumber,
                            issuedDate: sharedScript.issuedDate?.date(),
                            expiryDate: sharedScript.expiryDate?.date(),
                            repeatsAuthorised: sharedScript.repeatsAuthorised,
                            repeatsRemaining: sharedScript.repeatsRemaining,
                            prescriber: sharedScript.prescriber,
                            lastReviewedAt: sharedScript.lastReviewedAt,
                            notes: sharedScript.notes
                        )
                        context.insert(script)
                        knownScriptIDs.insert(sharedScript.id)
                        addedScripts += 1
                    }
                }

                for planID in touchedPlanIDs {
                    importPlansBySourceID[planID]?.updateDates()
                }
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }

        return CareShareImportSummary(
            addedMedicines: addedMedicines,
            addedRefillScripts: addedScripts,
            skippedMedicines: skippedMedicines
        )
    }
}

@ModelActor
actor CareShareImporter {
    func importPackage(
        _ package: CareSharePackage
    ) throws -> CareShareImportSummary {
        try CareShareService.importPackage(package, context: modelContext)
    }
}

struct CareShareImportSummary: Sendable {
    let addedMedicines: Int
    let addedRefillScripts: Int
    let skippedMedicines: Int
}

enum CareShareError: LocalizedError {
    case archiveTooLarge
    case unsupportedVersion
    case tooManyRecords
    case invalidMedicine
    case invalidRefillScript

    var errorDescription: String? {
        switch self {
        case .archiveTooLarge:
            "This care snapshot is too large to import safely."
        case .unsupportedVersion:
            "This care snapshot was created by an unsupported app version."
        case .tooManyRecords:
            "This care snapshot contains too many records."
        case .invalidMedicine:
            "This care snapshot contains invalid medication data."
        case .invalidRefillScript:
            "This care snapshot contains invalid refill-script data."
        }
    }
}
