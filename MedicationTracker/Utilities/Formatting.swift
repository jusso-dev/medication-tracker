import Foundation

extension Decimal {
    var medicationFormatted: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var medicationDecimal: Decimal? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "½":
            return Decimal(string: "0.5")
        case "⅓":
            return Decimal(string: "0.333")
        case "¼":
            return Decimal(string: "0.25")
        case "¾":
            return Decimal(string: "0.75")
        default:
            let commaCount = trimmed.filter { $0 == "," }.count
            if commaCount == 1, !trimmed.contains(".") {
                return Decimal(
                    string: trimmed.replacingOccurrences(of: ",", with: "."),
                    locale: Locale(identifier: "en_US_POSIX")
                )
            }
            return Decimal(string: trimmed, locale: Locale(identifier: "en_AU"))
        }
    }
}

extension Date {
    var shortMedicationDate: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }

    var longMedicationDate: String {
        formatted(.dateTime.day().month(.wide).year())
    }

    var medicationTime: String {
        formatted(date: .omitted, time: .shortened)
    }

    var monthAndYear: String {
        formatted(.dateTime.month(.wide).year())
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var minutesFromMidnight: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

extension Int {
    var medicationTime: String {
        let normalised = ((self % 1_440) + 1_440) % 1_440
        let start = Calendar.current.startOfDay(for: .now)
        let date = Calendar.current.date(byAdding: .minute, value: normalised, to: start) ?? start
        return date.medicationTime
    }
}

extension Calendar {
    func date(on day: Date, minutesFromMidnight: Int) -> Date? {
        let normalised = ((minutesFromMidnight % 1_440) + 1_440) % 1_440
        return date(
            bySettingHour: normalised / 60,
            minute: normalised % 60,
            second: 0,
            of: day
        )
    }
}
