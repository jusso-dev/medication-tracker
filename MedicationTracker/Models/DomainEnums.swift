import Foundation

enum MedicineUnit: String, Codable, CaseIterable, Identifiable {
    case tablet
    case capsule
    case mg
    case mL
    case g
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mL:
            "mL"
        default:
            rawValue
        }
    }

    func displayName(for amount: Decimal) -> String {
        guard amount != 1 else { return displayName }

        return switch self {
        case .tablet:
            "tablets"
        case .capsule:
            "capsules"
        default:
            displayName
        }
    }

    var subtractsDoseAmount: Bool {
        self == .tablet || self == .capsule
    }
}

enum MedicineStatus: String, Codable, CaseIterable {
    case active
    case completed
    case deleted
}

enum TreatmentPlanStatus: String, Codable, CaseIterable {
    case active
    case completed
}

enum DoseOutcome: String, Codable, CaseIterable {
    case taken
    case skipped
    case late
    case snoozed
    case loggedAsNeeded

    var displayName: String {
        switch self {
        case .taken:
            "Taken"
        case .skipped:
            "Skipped"
        case .late:
            "Taken late"
        case .snoozed:
            "Snoozed"
        case .loggedAsNeeded:
            "Logged"
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case history
    case today
    case medications
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history:
            "History"
        case .today:
            "Today"
        case .medications:
            "Medications"
        case .settings:
            "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .history:
            "clock.arrow.circlepath"
        case .today:
            "house"
        case .medications:
            "pill"
        case .settings:
            "gearshape"
        }
    }
}
