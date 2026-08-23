import Foundation

struct ScheduledTime: Identifiable, Hashable, Sendable {
    let id: UUID
    var minutes: Int

    init(id: UUID = UUID(), minutes: Int) {
        self.id = id
        self.minutes = minutes
    }
}
