import Foundation

struct CalendarDay: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1970
        month = components.month ?? 1
        day = components.day ?? 1
    }

    func date(timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        ) else {
            return nil
        }
        let result = calendar.dateComponents([.year, .month, .day], from: date)
        guard result.year == year, result.month == month, result.day == day else {
            return nil
        }
        return date
    }

    var displayText: String {
        guard let date = date() else { return "Invalid date" }
        return date.longMedicationDate
    }
}
