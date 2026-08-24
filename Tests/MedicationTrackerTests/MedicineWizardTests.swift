import Foundation
import SwiftData
import Testing
import UIKit
@testable import MedicationTracker

@MainActor
@Suite("Medicine wizard")
struct MedicineWizardTests {
    @Test("Time rows keep stable identity while the slider changes their value")
    func timeEntryIdentityIsStable() {
        let draft = MedicineDraft()
        draft.addTime()
        let entry = draft.scheduledTimes[0]

        #expect(draft.updateTime(id: entry.id, to: 1_080))
        #expect(draft.scheduledTimes[0].id == entry.id)
        #expect(draft.scheduledTimes[0].minutes == 1_080)
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

    @Test("Retrospective medication images are prepared for local storage")
    func retrospectiveMedicationImagePreparation() throws {
        let sourceData = UIGraphicsImageRenderer(
            size: CGSize(width: 2_400, height: 1_600)
        ).jpegData(withCompressionQuality: 1) { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_600))
        }

        let storedData = try #require(
            MedicationOCRService.preparedStoredImage(from: sourceData)
        )
        let storedImage = try #require(UIImage(data: storedData))

        #expect(max(storedImage.size.width, storedImage.size.height) <= 1_800)
        #expect(MedicationOCRService.preparedStoredImage(from: Data()) == nil)
    }
}
