import SwiftData

@MainActor
enum CalendarDayMigration {
    static func migrateIfNeeded(context: ModelContext) throws {
        let medicines = try context.fetch(FetchDescriptor<Medicine>())
        let plans = try context.fetch(FetchDescriptor<TreatmentPlan>())
        let scripts = try context.fetch(FetchDescriptor<RefillScript>())
        let needsMigration = medicines.contains {
            $0.startDay == nil
                || ($0.endDay == nil && $0.legacyEndDate != nil)
                || ($0.packageExpiryDay == nil && $0.legacyPackageExpiryDate != nil)
        } || plans.contains {
            ($0.startDay == nil && $0.legacyStartDate != nil)
                || ($0.endDay == nil && $0.legacyEndDate != nil)
        } || scripts.contains {
            ($0.issuedDay == nil && $0.legacyIssuedDate != nil)
                || ($0.expiryDay == nil && $0.legacyExpiryDate != nil)
        }
        guard needsMigration else { return }

        medicines.forEach { $0.migrateCalendarDaysIfNeeded() }
        plans.forEach { $0.migrateCalendarDaysIfNeeded() }
        scripts.forEach { $0.migrateCalendarDaysIfNeeded() }
        try context.save()
    }
}
