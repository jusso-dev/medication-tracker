import Foundation
import SwiftData

@Model
final class Medicine {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var unitRawValue: String
    var asNeeded: Bool
    var daysOfWeek: [Int]
    var times: [Int]
    var intervalMinutes: Int?
    var intervalLinked: Bool
    @Attribute(originalName: "startDate") var legacyStartDate: Date
    @Attribute(originalName: "endDate") var legacyEndDate: Date?
    var startDay: CalendarDay?
    var endDay: CalendarDay?
    var remindersOn: Bool
    var notes: String?
    @Attribute(.externalStorage) var scannedImageData: Data?
    @Attribute(originalName: "packageExpiryDate")
    var legacyPackageExpiryDate: Date?
    var packageExpiryDay: CalendarDay?
    var dailyCap: Int?
    var quantityRemaining: Decimal?
    var refillAt: Decimal?
    var lowStockNotificationSent: Bool
    var statusRawValue: String
    var completedAt: Date?
    @Relationship(inverse: \TreatmentPlan.medicines) var plan: TreatmentPlan?
    @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medicine)
    var doseEvents: [DoseEvent]
    @Relationship(deleteRule: .cascade, inverse: \RefillScript.medicine)
    var refillScripts: [RefillScript]

    var unit: MedicineUnit {
        get { MedicineUnit(rawValue: unitRawValue) ?? .other }
        set { unitRawValue = newValue.rawValue }
    }

    var status: MedicineStatus {
        get { MedicineStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var packageExpiryDate: Date? {
        get { packageExpiryDay?.date() ?? legacyPackageExpiryDate }
        set {
            packageExpiryDay = newValue.map { CalendarDay($0) }
            legacyPackageExpiryDate = nil
        }
    }

    var startDate: Date {
        get { startDay?.date() ?? legacyStartDate }
        set {
            startDay = CalendarDay(newValue)
            legacyStartDate = newValue.startOfDay
        }
    }

    var endDate: Date? {
        get { endDay?.date() ?? legacyEndDate }
        set {
            endDay = newValue.map { CalendarDay($0) }
            legacyEndDate = nil
        }
    }

    var strengthText: String {
        "\(amount.medicationFormatted) \(unit.displayName(for: amount))"
    }

    var displayName: String {
        "\(name) \(strengthText)"
    }

    var shortScheduleLabel: String {
        asNeeded ? "As needed" : "\(times.count)x"
    }

    var sortedTimes: [Int] {
        times.sorted()
    }

    /// Alias used by the product-fixes UI. Same bytes as `scannedImageData`.
    var scanImageData: Data? {
        get { scannedImageData }
        set { scannedImageData = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        unit: MedicineUnit,
        asNeeded: Bool,
        daysOfWeek: [Int] = [],
        times: [Int] = [],
        intervalMinutes: Int? = nil,
        intervalLinked: Bool = false,
        startDate: Date,
        endDate: Date? = nil,
        remindersOn: Bool = false,
        notes: String? = nil,
        scannedImageData: Data? = nil,
        packageExpiryDate: Date? = nil,
        dailyCap: Int? = nil,
        quantityRemaining: Decimal? = nil,
        refillAt: Decimal? = nil,
        status: MedicineStatus = .active,
        plan: TreatmentPlan? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = amount
        self.unitRawValue = unit.rawValue
        self.asNeeded = asNeeded
        self.daysOfWeek = daysOfWeek.sorted()
        self.times = times.sorted()
        self.intervalMinutes = intervalMinutes
        self.intervalLinked = intervalLinked
        self.legacyStartDate = Calendar.current.startOfDay(for: startDate)
        self.legacyEndDate = nil
        self.startDay = CalendarDay(startDate)
        self.endDay = endDate.map { CalendarDay($0) }
        self.remindersOn = remindersOn
        self.notes = notes?.nilIfBlank
        self.scannedImageData = scannedImageData
        self.legacyPackageExpiryDate = nil
        self.packageExpiryDay = packageExpiryDate.map { CalendarDay($0) }
        self.dailyCap = dailyCap
        self.quantityRemaining = quantityRemaining
        self.refillAt = refillAt
        self.lowStockNotificationSent = false
        self.statusRawValue = status.rawValue
        self.plan = plan
        self.doseEvents = []
        self.refillScripts = []
    }

    func migrateCalendarDaysIfNeeded() {
        if startDay == nil {
            startDay = CalendarDay(legacyStartDate)
        }
        if endDay == nil, let legacyEndDate {
            endDay = CalendarDay(legacyEndDate)
            self.legacyEndDate = nil
        }
        if packageExpiryDay == nil, let legacyPackageExpiryDate {
            packageExpiryDay = CalendarDay(legacyPackageExpiryDate)
            self.legacyPackageExpiryDate = nil
        }
    }
}
