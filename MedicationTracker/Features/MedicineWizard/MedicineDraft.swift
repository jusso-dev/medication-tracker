import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MedicineDraft {
    var name = ""
    var amountText = ""
    var unit: MedicineUnit = .tablet
    var daysOfWeek: Set<Int> = []
    var times: [Int] = []
    var intervalMinutes: Int?
    var intervalLinked = false
    var remindersOn = false
    var startDate = Date.now.startOfDay
    var endDate: Date?
    var isOngoing = false
    var durationUnit: DurationUnit = .days
    var durationValue = 0
    var notes = ""
    var packageExpiryDate: Date?
    var packageExpiryEnabled = false
    var dailyCapText = ""
    var quantityText = ""
    var refillAtText = "5"
    var dayPreset: String?
    var timePreset: String?

    let medicine: Medicine?

    var parsedAmount: Decimal? {
        amountText.medicationDecimal
    }

    var hasValidName: Bool {
        name.nilIfBlank != nil
    }

    var hasValidAmount: Bool {
        guard let parsedAmount else { return false }
        return parsedAmount > 0
    }

    var scheduleIsValid: Bool {
        (daysOfWeek.isEmpty && times.isEmpty)
            || (!daysOfWeek.isEmpty && !times.isEmpty)
    }

    var durationIsValid: Bool {
        isOngoing || endDate != nil
    }

    var isAsNeeded: Bool {
        daysOfWeek.isEmpty && times.isEmpty
    }

    var contextLine: String {
        guard let amount = parsedAmount else { return name }
        return "\(name) \(amount.medicationFormatted) \(unit.displayName(for: amount))"
    }

    init(medicine: Medicine? = nil) {
        self.medicine = medicine
        guard let medicine else { return }

        name = medicine.name
        amountText = medicine.amount.medicationFormatted
        unit = medicine.unit
        daysOfWeek = Set(medicine.daysOfWeek)
        times = medicine.times.sorted()
        intervalMinutes = medicine.intervalMinutes
        intervalLinked = medicine.intervalLinked
        remindersOn = medicine.remindersOn
        startDate = medicine.startDate
        endDate = medicine.endDate
        isOngoing = medicine.endDate == nil
        notes = medicine.notes ?? ""
        packageExpiryDate = medicine.packageExpiryDate
        packageExpiryEnabled = medicine.packageExpiryDate != nil
        dailyCapText = medicine.dailyCap.map(String.init) ?? ""
        quantityText = medicine.quantityRemaining?.medicationFormatted ?? ""
        refillAtText = medicine.refillAt?.medicationFormatted ?? "5"
        updatePresetLabels()

        if let endDate {
            durationValue = ScheduleCalculator.durationValue(
                from: startDate,
                to: endDate,
                unit: durationUnit
            )
        }
    }

    func toggleDay(_ day: Int) {
        if daysOfWeek.contains(day) {
            daysOfWeek.remove(day)
        } else {
            daysOfWeek.insert(day)
        }
        updateDayPresetLabel()
    }

    func toggleAllDays() {
        daysOfWeek = daysOfWeek == Set(1...7) ? [] : Set(1...7)
        updateDayPresetLabel()
    }

    func clearSchedule() {
        daysOfWeek = []
        times = []
        intervalMinutes = nil
        intervalLinked = false
        remindersOn = false
        dayPreset = nil
        timePreset = nil
    }

    func cycleDayPreset() {
        if dayPreset == "Every other" {
            daysOfWeek = Set(1...7)
            dayPreset = "Every day"
        } else {
            daysOfWeek = [1, 3, 5, 7]
            dayPreset = "Every other"
        }
    }

    func cycleTimePreset() {
        if timePreset == "Every 12h" {
            times = [0, 480, 960]
            intervalMinutes = 480
            timePreset = "Every 8h"
        } else {
            times = [0, 720]
            intervalMinutes = 720
            timePreset = "Every 12h"
        }
        intervalLinked = true
    }

    func addTime() {
        let proposed = times.last.map { ($0 + 60) % 1_440 } ?? 480
        times.append(proposed)
        times = Array(Set(times)).sorted()
        intervalMinutes = nil
        intervalLinked = false
        timePreset = nil
    }

    func removeTime(_ minutes: Int) {
        times.removeAll { $0 == minutes }
        intervalMinutes = nil
        intervalLinked = false
        timePreset = nil
    }

    @discardableResult
    func updateTime(from oldValue: Int, to newValue: Int) -> Bool {
        if intervalLinked {
            times = ScheduleCalculator.shiftedLinkedTimes(
                times,
                changing: oldValue,
                to: newValue
            )
            return true
        } else if let index = times.firstIndex(of: oldValue) {
            guard oldValue == newValue || !times.contains(newValue) else {
                return false
            }
            times[index] = newValue
            times.sort()
            return true
        }
        return false
    }

    func updateEndDateFromDuration() {
        guard !isOngoing else {
            endDate = nil
            return
        }
        endDate = ScheduleCalculator.endDate(
            from: startDate,
            value: durationValue,
            unit: durationUnit
        )
    }

    func setEndDate(_ date: Date) {
        isOngoing = false
        endDate = max(startDate, date.startOfDay)
        if let endDate {
            durationValue = ScheduleCalculator.durationValue(
                from: startDate,
                to: endDate,
                unit: durationUnit
            )
        }
    }

    func setOngoing() {
        isOngoing = true
        endDate = nil
    }

    func applyScan(_ result: MedicationScanResult) {
        if let medicineName = result.medicineName {
            name = medicineName
        }
        if let amount = result.amount {
            amountText = amount.medicationFormatted
        }
        if let unit = result.unit {
            self.unit = unit
        }
        if let expiryDate = result.expiryDate {
            packageExpiryDate = expiryDate
            packageExpiryEnabled = true
        }
    }

    func save(context: ModelContext, plan: TreatmentPlan? = nil) throws -> Medicine {
        guard let amount = parsedAmount, amount > 0 else {
            throw MedicineDraftError.invalidAmount
        }

        let dailyCap = Int(dailyCapText).flatMap { $0 > 0 ? $0 : nil }
        let quantity = quantityText.medicationDecimal.flatMap { $0 >= 0 ? $0 : nil }
        let refill = quantity == nil
            ? nil
            : refillAtText.medicationDecimal.flatMap { $0 >= 0 ? $0 : nil }

        let target: Medicine
        if let medicine {
            target = medicine
            target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            target.amount = amount
            target.unit = unit
            target.asNeeded = isAsNeeded
            target.daysOfWeek = daysOfWeek.sorted()
            target.times = times.sorted()
            target.intervalMinutes = intervalMinutes
            target.intervalLinked = intervalLinked
            target.startDate = startDate.startOfDay
            target.endDate = isOngoing ? nil : endDate?.startOfDay
            target.remindersOn = remindersOn && !isAsNeeded
            target.notes = notes.nilIfBlank
            target.packageExpiryDate = packageExpiryEnabled
                ? packageExpiryDate?.startOfDay
                : nil
            target.dailyCap = dailyCap
            target.quantityRemaining = quantity
            target.refillAt = refill
            if let plan {
                target.plan = plan
            }
        } else {
            target = Medicine(
                name: name,
                amount: amount,
                unit: unit,
                asNeeded: isAsNeeded,
                daysOfWeek: daysOfWeek.sorted(),
                times: times.sorted(),
                intervalMinutes: intervalMinutes,
                intervalLinked: intervalLinked,
                startDate: startDate,
                endDate: isOngoing ? nil : endDate,
                remindersOn: remindersOn && !isAsNeeded,
                notes: notes,
                packageExpiryDate: packageExpiryEnabled ? packageExpiryDate : nil,
                dailyCap: dailyCap,
                quantityRemaining: quantity,
                refillAt: refill,
                plan: plan
            )
            context.insert(target)
        }

        if let quantity, let refill, quantity > refill {
            target.lowStockNotificationSent = false
        }
        target.plan?.updateDates()
        try context.save()
        return target
    }

    private func updatePresetLabels() {
        updateDayPresetLabel()
        if intervalLinked && intervalMinutes == 480 {
            timePreset = "Every 8h"
        } else if intervalLinked && intervalMinutes == 720 {
            timePreset = "Every 12h"
        }
    }

    private func updateDayPresetLabel() {
        if daysOfWeek == Set(1...7) {
            dayPreset = "Every day"
        } else if daysOfWeek == Set([1, 3, 5, 7]) {
            dayPreset = "Every other"
        } else {
            dayPreset = nil
        }
    }
}

enum MedicineDraftError: Error {
    case invalidAmount
}
