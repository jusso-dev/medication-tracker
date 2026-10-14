import Foundation
import SwiftData

struct BackupManifest: Codable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var medicines: [BackupMedicine]
    var treatmentPlans: [BackupTreatmentPlan]
    var doseEvents: [BackupDoseEvent]
    var refillScripts: [BackupRefillScript]
}

struct BackupMedicine: Codable, Sendable {
    var id: UUID
    var name: String
    var amount: Decimal
    var unitRawValue: String
    var asNeeded: Bool
    var daysOfWeek: [Int]
    var times: [Int]
    var intervalMinutes: Int?
    var intervalLinked: Bool
    var startDate: CalendarDay
    var endDate: CalendarDay?
    var remindersOn: Bool
    var notes: String?
    var packageExpiryDate: CalendarDay?
    var dailyCap: Int?
    var quantityRemaining: Decimal?
    var refillAt: Decimal?
    var lowStockNotificationSent: Bool
    var statusRawValue: String
    var completedAt: Date?
    var scannedImageDataBase64: String?
    var planID: UUID?

    init(_ medicine: Medicine) {
        id = medicine.id
        name = medicine.name
        amount = medicine.amount
        unitRawValue = medicine.unitRawValue
        asNeeded = medicine.asNeeded
        daysOfWeek = medicine.daysOfWeek
        times = medicine.times
        intervalMinutes = medicine.intervalMinutes
        intervalLinked = medicine.intervalLinked
        startDate = CalendarDay(medicine.startDate)
        endDate = medicine.endDate.map { CalendarDay($0) }
        remindersOn = medicine.remindersOn
        notes = medicine.notes
        packageExpiryDate = medicine.packageExpiryDate.map { CalendarDay($0) }
        dailyCap = medicine.dailyCap
        quantityRemaining = medicine.quantityRemaining
        refillAt = medicine.refillAt
        lowStockNotificationSent = medicine.lowStockNotificationSent
        statusRawValue = medicine.statusRawValue
        completedAt = medicine.completedAt
        scannedImageDataBase64 = medicine.scannedImageData?.base64EncodedString()
        planID = medicine.plan?.id
    }
}

struct BackupTreatmentPlan: Codable, Sendable {
    var id: UUID
    var title: String
    var prescriber: String?
    var startDate: CalendarDay?
    var endDate: CalendarDay?
    var statusRawValue: String
    var completedAt: Date?

    init(_ plan: TreatmentPlan) {
        id = plan.id
        title = plan.title
        prescriber = plan.prescriber
        startDate = plan.startDate.map { CalendarDay($0) }
        endDate = plan.endDate.map { CalendarDay($0) }
        statusRawValue = plan.statusRawValue
        completedAt = plan.completedAt
    }
}

struct BackupDoseEvent: Codable, Sendable {
    var id: UUID
    var scheduledAt: Date?
    var takenAt: Date?
    var outcomeRawValue: String
    var medicineID: UUID

    init(_ event: DoseEvent) {
        id = event.id
        scheduledAt = event.scheduledAt
        takenAt = event.takenAt
        outcomeRawValue = event.outcomeRawValue
        medicineID = event.medicine?.id ?? UUID()
    }
}

struct BackupRefillScript: Codable, Sendable {
    var id: UUID
    var scriptNumber: String?
    var issuedDate: CalendarDay?
    var expiryDate: CalendarDay?
    var repeatsAuthorised: Int?
    var repeatsRemaining: Int
    var prescriber: String?
    var lastReviewedAt: Date?
    var notes: String?
    var medicineID: UUID?

    init(_ script: RefillScript) {
        id = script.id
        scriptNumber = script.scriptNumber
        issuedDate = script.issuedDate.map { CalendarDay($0) }
        expiryDate = script.expiryDate.map { CalendarDay($0) }
        repeatsAuthorised = script.repeatsAuthorised
        repeatsRemaining = script.repeatsRemaining
        prescriber = script.prescriber
        lastReviewedAt = script.lastReviewedAt
        notes = script.notes
        medicineID = script.medicine?.id
    }
}
