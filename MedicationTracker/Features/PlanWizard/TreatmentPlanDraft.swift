import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TreatmentPlanDraft {
    var title = ""
    var prescriber = ""
    var selectedMedicineIDs: Set<UUID> = []

    let plan: TreatmentPlan?

    var hasValidTitle: Bool {
        title.nilIfBlank != nil
    }

    init(plan: TreatmentPlan? = nil) {
        self.plan = plan
        guard let plan else { return }
        title = plan.title
        prescriber = plan.prescriber ?? ""
        selectedMedicineIDs = Set(plan.medicines.map(\.id))
    }

    func toggleMedicine(_ medicine: Medicine) {
        if selectedMedicineIDs.contains(medicine.id) {
            selectedMedicineIDs.remove(medicine.id)
        } else {
            selectedMedicineIDs.insert(medicine.id)
        }
    }

    func save(
        context: ModelContext,
        allMedicines: [Medicine]
    ) throws -> TreatmentPlan {
        let target: TreatmentPlan
        if let plan {
            target = plan
            target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            target.prescriber = prescriber.nilIfBlank

            for medicine in plan.medicines
            where medicine.status == .active
                && !selectedMedicineIDs.contains(medicine.id) {
                medicine.plan = nil
            }
        } else {
            target = TreatmentPlan(title: title, prescriber: prescriber)
            context.insert(target)
        }

        let selected = allMedicines.filter {
            selectedMedicineIDs.contains($0.id) && $0.status == .active
        }
        for medicine in selected {
            medicine.plan = target
        }
        let historicalMembers = target.medicines.filter { $0.status != .active }
        target.medicines = historicalMembers + selected
        target.updateDates()
        try context.save()
        return target
    }
}
