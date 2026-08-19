import Foundation
import SwiftData

@Model
final class TreatmentPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var prescriber: String?
    @Attribute(originalName: "startDate") var legacyStartDate: Date?
    @Attribute(originalName: "endDate") var legacyEndDate: Date?
    var startDay: CalendarDay?
    var endDay: CalendarDay?
    var statusRawValue: String
    var completedAt: Date?
    @Relationship(deleteRule: .nullify) var medicines: [Medicine]

    var status: TreatmentPlanStatus {
        get { TreatmentPlanStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var startDate: Date? {
        get { startDay?.date() ?? legacyStartDate }
        set {
            startDay = newValue.map { CalendarDay($0) }
            legacyStartDate = nil
        }
    }

    var endDate: Date? {
        get { endDay?.date() ?? legacyEndDate }
        set {
            endDay = newValue.map { CalendarDay($0) }
            legacyEndDate = nil
        }
    }

    var prescriberDisplayName: String {
        prescriber?.nilIfBlank ?? "Self-managed"
    }

    var activeMedicines: [Medicine] {
        medicines
            .filter { $0.status == .active }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    init(
        id: UUID = UUID(),
        title: String,
        prescriber: String? = nil,
        medicines: [Medicine] = [],
        status: TreatmentPlanStatus = .active
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prescriber = prescriber?.nilIfBlank
        self.legacyStartDate = nil
        self.legacyEndDate = nil
        self.startDay = nil
        self.endDay = nil
        self.statusRawValue = status.rawValue
        self.medicines = medicines
        updateDates()
    }

    func updateDates() {
        let active = medicines.filter { $0.status == .active }
        startDate = active.map(\.startDate).min()
        endDate = active.contains(where: { $0.endDate == nil })
            ? nil
            : active.compactMap(\.endDate).max()
    }

    func migrateCalendarDaysIfNeeded() {
        if startDay == nil, let legacyStartDate {
            startDay = CalendarDay(legacyStartDate)
            self.legacyStartDate = nil
        }
        if endDay == nil, let legacyEndDate {
            endDay = CalendarDay(legacyEndDate)
            self.legacyEndDate = nil
        }
    }
}
