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
    var startDate: Date
    var endDate: Date?
    var remindersOn: Bool
    var notes: String?
    var dailyCap: Int?
    var quantityRemaining: Decimal?
    var refillAt: Decimal?
    var lowStockNotificationSent: Bool
    var statusRawValue: String
    var completedAt: Date?
    @Relationship(inverse: \TreatmentPlan.medicines) var plan: TreatmentPlan?
    @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medicine)
    var doseEvents: [DoseEvent]

    var unit: MedicineUnit {
        get { MedicineUnit(rawValue: unitRawValue) ?? .other }
        set { unitRawValue = newValue.rawValue }
    }

    var status: MedicineStatus {
        get { MedicineStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
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
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = endDate.map { Calendar.current.startOfDay(for: $0) }
        self.remindersOn = remindersOn
        self.notes = notes?.nilIfBlank
        self.dailyCap = dailyCap
        self.quantityRemaining = quantityRemaining
        self.refillAt = refillAt
        self.lowStockNotificationSent = false
        self.statusRawValue = status.rawValue
        self.plan = plan
        self.doseEvents = []
    }
}
