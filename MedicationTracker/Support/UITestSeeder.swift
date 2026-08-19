import Foundation
import SwiftData

@MainActor
enum UITestSeeder {
    static func seed(context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<Medicine>()) == 0 else {
            return
        }

        let calendar = Calendar.current
        let today = Date.now.startOfDay
        let nowMinutes = Date.now.minutesFromMidnight
        let weekday = calendar.component(.weekday, from: .now)
        let endDate = calendar.date(byAdding: .day, value: 7, to: today)
        let packageExpiry = calendar.date(byAdding: .year, value: 1, to: today)

        let plan = TreatmentPlan(
            title: "Tooth Infection",
            prescriber: "Dr. Chen"
        )
        let amoxicillin = Medicine(
            name: "Amoxicillin",
            amount: 500,
            unit: .mg,
            asNeeded: false,
            daysOfWeek: [weekday],
            times: [nowMinutes],
            startDate: today,
            endDate: endDate,
            remindersOn: false,
            notes: "With food",
            packageExpiryDate: packageExpiry,
            plan: plan
        )
        let script = RefillScript(
            medicine: amoxicillin,
            scriptNumber: "RX-TEST",
            expiryDate: packageExpiry,
            repeatsAuthorised: 5,
            repeatsRemaining: 3,
            prescriber: "Dr. Chen",
            lastReviewedAt: .now
        )
        let ibuprofen = Medicine(
            name: "Ibuprofen",
            amount: 400,
            unit: .mg,
            asNeeded: true,
            startDate: today,
            endDate: endDate,
            dailyCap: 1,
            quantityRemaining: 20,
            refillAt: 5
        )
        let completed = Medicine(
            name: "Paracetamol",
            amount: 500,
            unit: .mg,
            asNeeded: true,
            startDate: calendar.date(byAdding: .day, value: -7, to: today) ?? today,
            endDate: calendar.date(byAdding: .day, value: -1, to: today),
            status: .completed
        )
        completed.completedAt = calendar.date(byAdding: .day, value: -1, to: .now)

        context.insert(plan)
        context.insert(amoxicillin)
        context.insert(script)
        context.insert(ibuprofen)
        context.insert(completed)
        plan.updateDates()
        try context.save()
    }

    static func importPackage() -> CareSharePackage {
        let medicine = SharedMedicine(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            name: "Shared Cetirizine",
            amount: 10,
            unitRawValue: MedicineUnit.mg.rawValue,
            asNeeded: true,
            daysOfWeek: [],
            times: [],
            intervalMinutes: nil,
            intervalLinked: false,
            startDate: CalendarDay(.now),
            endDate: nil,
            notes: "Shared by someone you trust",
            dailyCap: nil,
            quantityRemaining: nil,
            refillAt: nil,
            packageExpiryDate: nil,
            planID: nil,
            refillScripts: []
        )
        return CareSharePackage(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            medicines: [medicine],
            treatmentPlans: []
        )
    }
}
