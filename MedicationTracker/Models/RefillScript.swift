import Foundation
import SwiftData

enum RefillScriptStatus: String {
    case valid
    case expired
    case noRepeats
    case reviewNeeded

    var title: String {
        switch self {
        case .valid:
            "Valid"
        case .expired:
            "Expired"
        case .noRepeats:
            "No repeats"
        case .reviewNeeded:
            "Review needed"
        }
    }
}

@Model
final class RefillScript {
    @Attribute(.unique) var id: UUID
    var scriptNumber: String?
    @Attribute(originalName: "issuedDate") var legacyIssuedDate: Date?
    @Attribute(originalName: "expiryDate") var legacyExpiryDate: Date?
    var issuedDay: CalendarDay?
    var expiryDay: CalendarDay?
    var repeatsAuthorised: Int?
    var repeatsRemaining: Int
    var prescriber: String?
    var lastReviewedAt: Date?
    var notes: String?
    var medicine: Medicine?

    var issuedDate: Date? {
        get { issuedDay?.date() ?? legacyIssuedDate }
        set {
            issuedDay = newValue.map { CalendarDay($0) }
            legacyIssuedDate = nil
        }
    }

    var expiryDate: Date? {
        get { expiryDay?.date() ?? legacyExpiryDate }
        set {
            expiryDay = newValue.map { CalendarDay($0) }
            legacyExpiryDate = nil
        }
    }

    var status: RefillScriptStatus {
        if repeatsRemaining <= 0 {
            return .noRepeats
        }
        guard let expiryDate else {
            return .reviewNeeded
        }
        return expiryDate.startOfDay < Date.now.startOfDay ? .expired : .valid
    }

    init(
        id: UUID = UUID(),
        medicine: Medicine? = nil,
        scriptNumber: String? = nil,
        issuedDate: Date? = nil,
        expiryDate: Date? = nil,
        repeatsAuthorised: Int? = nil,
        repeatsRemaining: Int = 0,
        prescriber: String? = nil,
        lastReviewedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.medicine = medicine
        self.scriptNumber = scriptNumber?.nilIfBlank
        self.legacyIssuedDate = nil
        self.legacyExpiryDate = nil
        self.issuedDay = issuedDate.map { CalendarDay($0) }
        self.expiryDay = expiryDate.map { CalendarDay($0) }
        self.repeatsAuthorised = repeatsAuthorised
        self.repeatsRemaining = max(0, repeatsRemaining)
        self.prescriber = prescriber?.nilIfBlank
        self.lastReviewedAt = lastReviewedAt
        self.notes = notes?.nilIfBlank
    }

    func recordRefill() {
        repeatsRemaining = max(0, repeatsRemaining - 1)
        lastReviewedAt = .now
    }

    func migrateCalendarDaysIfNeeded() {
        if issuedDay == nil, let legacyIssuedDate {
            issuedDay = CalendarDay(legacyIssuedDate)
            self.legacyIssuedDate = nil
        }
        if expiryDay == nil, let legacyExpiryDate {
            expiryDay = CalendarDay(legacyExpiryDate)
            self.legacyExpiryDate = nil
        }
    }
}
