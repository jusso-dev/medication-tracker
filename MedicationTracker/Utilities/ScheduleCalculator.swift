import Foundation

struct MedicationSchedule: Sendable {
    let daysOfWeek: [Int]
    let times: [Int]
    let startDate: Date
    let endDate: Date?
    let leadTimeMinutes: Int
}

enum DurationUnit: String, CaseIterable, Identifiable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"

    var id: String { rawValue }
}

enum ScheduleCalculator {
    static func doseDates(
        for schedule: MedicationSchedule,
        after now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0,
              !schedule.daysOfWeek.isEmpty,
              !schedule.times.isEmpty else {
            return []
        }

        let allowedDays = Set(schedule.daysOfWeek)
        let start = calendar.startOfDay(for: schedule.startDate)
        let finalDay = schedule.endDate.map { calendar.startOfDay(for: $0) }
        var day = max(start, calendar.startOfDay(for: now))
        var results: [Date] = []
        var inspectedDays = 0

        while results.count < limit && inspectedDays < 730 {
            if let finalDay, day > finalDay {
                break
            }

            let weekday = calendar.component(.weekday, from: day)
            if allowedDays.contains(weekday) {
                for minutes in schedule.times.sorted() {
                    guard let doseDate = calendar.date(on: day, minutesFromMidnight: minutes),
                          let fireDate = calendar.date(
                              byAdding: .minute,
                              value: -schedule.leadTimeMinutes,
                              to: doseDate
                          ),
                          fireDate > now else {
                        continue
                    }
                    results.append(doseDate)
                    if results.count == limit {
                        break
                    }
                }
            }

            inspectedDays += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }

        return results
    }

    static func doseDates(
        on day: Date,
        schedule: MedicationSchedule,
        calendar: Calendar = .current
    ) -> [Date] {
        let target = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: schedule.startDate)
        if target < start {
            return []
        }
        if let endDate = schedule.endDate,
           target > calendar.startOfDay(for: endDate) {
            return []
        }

        let weekday = calendar.component(.weekday, from: target)
        guard schedule.daysOfWeek.contains(weekday) else {
            return []
        }

        return schedule.times
            .sorted()
            .compactMap { calendar.date(on: target, minutesFromMidnight: $0) }
    }

    static func endDate(
        from startDate: Date,
        value: Int,
        unit: DurationUnit,
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: startDate)
        switch unit {
        case .days:
            return calendar.date(byAdding: .day, value: value, to: start) ?? start
        case .weeks:
            return calendar.date(byAdding: .day, value: value * 7, to: start) ?? start
        case .months:
            return calendar.date(byAdding: .month, value: value, to: start) ?? start
        }
    }

    static func durationValue(
        from startDate: Date,
        to endDate: Date,
        unit: DurationUnit,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        switch unit {
        case .days:
            return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        case .weeks:
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return max(0, Int(round(Double(days) / 7)))
        case .months:
            return max(0, calendar.dateComponents([.month], from: start, to: end).month ?? 0)
        }
    }

    static func shiftedLinkedTimes(
        _ times: [Int],
        changing oldValue: Int,
        to newValue: Int
    ) -> [Int] {
        let delta = newValue - oldValue
        return times.map { (($0 + delta) % 1_440 + 1_440) % 1_440 }.sorted()
    }
}
