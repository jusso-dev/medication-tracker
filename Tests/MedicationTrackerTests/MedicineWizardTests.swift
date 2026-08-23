import Foundation
import SwiftData
import Testing
@testable import MedicationTracker

@MainActor
@Suite("Medicine wizard")
struct MedicineWizardTests {
    @Test("Time rows keep stable identity while the slider changes their value")
    func timeEntryIdentityIsStable() {
        let draft = MedicineDraft()
        draft.addTime()
        let entry = draft.timeEntries[0]

        #expect(draft.updateTime(id: entry.id, to: 1_080))
        #expect(draft.timeEntries[0].id == entry.id)
        #expect(draft.timeEntries[0].minutes == 1_080)
    }

    @Test("Decimal half strengths save as an ongoing medication")
    func decimalHalfStrength() throws {
        let container = try MedicationDataStore.makeContainer(
            isStoredInMemoryOnly: true
        )
        let draft = MedicineDraft()
        draft.name = "Prednisolone"
        draft.amountText = "12.5"
        draft.unit = .mg
        draft.setOngoing()

        let medicine = try draft.save(context: container.mainContext)

        #expect(medicine.amount == Decimal(string: "12.5"))
        #expect(medicine.strengthText == "12.5 mg")
        #expect(medicine.endDate == nil)
    }
}
