import Foundation
import SwiftData

@Model
final class DoseEvent {
    @Attribute(.unique) var id: UUID
    var scheduledAt: Date?
    var takenAt: Date?
    var outcomeRawValue: String
    var medicine: Medicine?

    var outcome: DoseOutcome {
        get { DoseOutcome(rawValue: outcomeRawValue) ?? .taken }
        set { outcomeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        medicine: Medicine,
        scheduledAt: Date? = nil,
        takenAt: Date? = nil,
        outcome: DoseOutcome
    ) {
        self.id = id
        self.medicine = medicine
        self.scheduledAt = scheduledAt
        self.takenAt = takenAt
        self.outcomeRawValue = outcome.rawValue
    }
}
