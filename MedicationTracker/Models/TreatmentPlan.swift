import Foundation
import SwiftData

@Model
final class TreatmentPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var prescriber: String?
    var startDate: Date?
    var endDate: Date?
    var statusRawValue: String
    var completedAt: Date?
    @Relationship(deleteRule: .nullify) var medicines: [Medicine]

    var status: TreatmentPlanStatus {
        get { TreatmentPlanStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
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
}
