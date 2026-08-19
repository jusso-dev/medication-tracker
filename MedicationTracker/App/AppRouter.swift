import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: AppTab = .medications
    var highlightedDoseID: String?

    private init() {}

    func openToday(medicineID: UUID, scheduledAt: Date?) {
        if let scheduledAt {
            highlightedDoseID = "\(medicineID.uuidString)-\(scheduledAt.timeIntervalSince1970)"
        } else {
            highlightedDoseID = medicineID.uuidString
        }
        selectedTab = .today
    }
}
