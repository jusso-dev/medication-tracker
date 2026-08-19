import SwiftData
import SwiftUI

@MainActor
enum PreviewData {
    static func emptyContainer() -> ModelContainer {
        makeContainer()
    }

    static func sampleContainer() -> ModelContainer {
        let container = makeContainer()
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 18
        )) ?? .now
        let end = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25
        )) ?? .now
        let scriptExpiry = calendar.date(from: DateComponents(
            year: 2027,
            month: 8,
            day: 25
        )) ?? .now

        let ibuprofen = Medicine(
            name: "Ibuprofen",
            amount: 400,
            unit: .mg,
            asNeeded: true,
            startDate: start,
            endDate: end
        )
        let amoxicillin = Medicine(
            name: "Amoxicillin",
            amount: 500,
            unit: .mg,
            asNeeded: false,
            daysOfWeek: Array(1...7),
            times: [30, 510, 990],
            intervalMinutes: 480,
            intervalLinked: true,
            startDate: start,
            endDate: end,
            remindersOn: true,
            packageExpiryDate: scriptExpiry
        )
        let refillScript = RefillScript(
            medicine: amoxicillin,
            scriptNumber: "RX-12345",
            expiryDate: scriptExpiry,
            repeatsAuthorised: 5,
            repeatsRemaining: 3,
            prescriber: "Dr. Chen",
            lastReviewedAt: start
        )
        let plan = TreatmentPlan(
            title: "Tooth Infection",
            prescriber: "Dr. Chen",
            medicines: [ibuprofen, amoxicillin]
        )
        ibuprofen.plan = plan
        amoxicillin.plan = plan
        container.mainContext.insert(plan)
        container.mainContext.insert(refillScript)
        try? container.mainContext.save()
        return container
    }

    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(
                for: Medicine.self,
                TreatmentPlan.self,
                DoseEvent.self,
                RefillScript.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create preview data: \(error)")
        }
    }
}

#Preview("Empty catalog") {
    MedicationsCatalogView()
        .environment(AppRouter.shared)
        .environment(NotificationManager.shared)
        .modelContainer(PreviewData.emptyContainer())
}

#Preview("Grouped catalog") {
    MedicationsCatalogView()
        .environment(AppRouter.shared)
        .environment(NotificationManager.shared)
        .modelContainer(PreviewData.sampleContainer())
}
