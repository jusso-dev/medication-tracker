import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct CareSharePackage: Codable, Identifiable, Sendable {
    static let currentSchemaVersion = 2

    let id: UUID
    let schemaVersion: Int
    let exportedAt: Date
    let medicines: [SharedMedicine]
    let treatmentPlans: [SharedTreatmentPlan]

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.currentSchemaVersion,
        exportedAt: Date = .now,
        medicines: [SharedMedicine],
        treatmentPlans: [SharedTreatmentPlan]
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.medicines = medicines
        self.treatmentPlans = treatmentPlans
    }
}

struct SharedMedicine: Codable, Identifiable, Sendable {
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
    let notes: String?
    let dailyCap: Int?
    let quantityRemaining: Decimal?
    let refillAt: Decimal?
    let packageExpiryDate: CalendarDay?
    let planID: UUID?
    let refillScripts: [SharedRefillScript]
}

struct SharedTreatmentPlan: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let prescriber: String?
}

struct SharedRefillScript: Codable, Identifiable, Sendable {
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

struct CareShareOptions: Equatable, Sendable {
    var includeNotes = false
    var includeInventory = false
    var includeRefillScripts = false
    var includePrescriberNames = false
}

struct CareShareDocument: Transferable, Sendable {
    let package: CareSharePackage

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .medicationCareSnapshot) { document in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Medication-Care-Snapshot-\(document.package.id.uuidString)")
                .appendingPathExtension("medcare")
            let data = try CareShareCodec.encode(document.package)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

extension UTType {
    static let medicationCareSnapshot = UTType(
        exportedAs: "dev.jusso.medicationtracker.care-snapshot",
        conformingTo: .json
    )
}
