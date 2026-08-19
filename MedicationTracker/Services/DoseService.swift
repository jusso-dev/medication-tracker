import Foundation
import SwiftData

@MainActor
enum DoseService {
    @discardableResult
    static func record(
        medicine: Medicine,
        outcome: DoseOutcome,
        scheduledAt: Date? = nil,
        at date: Date = .now,
        context: ModelContext
    ) throws -> Bool {
        if let scheduledAt,
           medicine.doseEvents.contains(where: {
               $0.outcome != .snoozed
                   && datesMatch($0.scheduledAt, scheduledAt)
           }) {
            return false
        }

        let existingSnooze = medicine.doseEvents.first {
            $0.outcome == .snoozed
                && datesMatch($0.scheduledAt, scheduledAt)
        }

        if let existingSnooze, outcome != .snoozed {
            existingSnooze.outcome = outcome
            existingSnooze.takenAt = date
        } else {
            let event = DoseEvent(
                medicine: medicine,
                scheduledAt: scheduledAt,
                takenAt: date,
                outcome: outcome
            )
            context.insert(event)
        }

        let consumesInventory = [.taken, .late, .loggedAsNeeded].contains(outcome)
        let reachedLowStock = consumesInventory ? decrementInventory(for: medicine) : false
        try context.save()
        return reachedLowStock
    }

    static func snooze(
        medicine: Medicine,
        scheduledAt: Date,
        until snoozedUntil: Date,
        context: ModelContext
    ) throws {
        guard !medicine.doseEvents.contains(where: {
            $0.outcome == .snoozed && datesMatch($0.scheduledAt, scheduledAt)
        }) else {
            return
        }

        let event = DoseEvent(
            medicine: medicine,
            scheduledAt: scheduledAt,
            takenAt: snoozedUntil,
            outcome: .snoozed
        )
        context.insert(event)
        try context.save()
    }

    static func canLogAsNeeded(
        medicine: Medicine,
        on day: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dailyCap = medicine.dailyCap else { return true }
        let count = medicine.doseEvents.filter { event in
            guard event.outcome == .loggedAsNeeded || event.outcome == .taken,
                  let takenAt = event.takenAt else {
                return false
            }
            return calendar.isDate(takenAt, inSameDayAs: day)
        }.count
        return count < dailyCap
    }

    static func event(
        for medicine: Medicine,
        scheduledAt: Date
    ) -> DoseEvent? {
        medicine.doseEvents.first {
            $0.outcome != .snoozed && datesMatch($0.scheduledAt, scheduledAt)
        }
    }

    static func snoozedEvent(
        for medicine: Medicine,
        scheduledAt: Date
    ) -> DoseEvent? {
        medicine.doseEvents.first {
            $0.outcome == .snoozed && datesMatch($0.scheduledAt, scheduledAt)
        }
    }

    private static func decrementInventory(for medicine: Medicine) -> Bool {
        guard let quantity = medicine.quantityRemaining else { return false }
        let decrement = medicine.unit.subtractsDoseAmount ? medicine.amount : 1
        medicine.quantityRemaining = max(0, quantity - decrement)

        guard let remaining = medicine.quantityRemaining,
              let refillAt = medicine.refillAt,
              remaining <= refillAt,
              !medicine.lowStockNotificationSent else {
            return false
        }

        return true
    }

    private static func datesMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case let (.some(lhs), .some(rhs)):
            abs(lhs.timeIntervalSince(rhs)) < 60
        default:
            false
        }
    }
}
