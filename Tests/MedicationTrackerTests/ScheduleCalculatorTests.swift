import Foundation
import Testing
@testable import MedicationTracker

@Suite("Schedule calculations")
struct ScheduleCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Seven days ends seven calendar days after the start")
    func sevenDayDuration() throws {
        let start = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 18
        )))

        let end = ScheduleCalculator.endDate(
            from: start,
            value: 7,
            unit: .days,
            calendar: calendar
        )

        #expect(calendar.component(.day, from: end) == 25)
    }

    @Test("Every eight hours produces three wall-clock doses")
    func everyEightHours() throws {
        let day = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 19
        )))
        let schedule = MedicationSchedule(
            daysOfWeek: [4],
            times: [30, 510, 990],
            startDate: day,
            endDate: day,
            leadTimeMinutes: 0
        )

        let doses = ScheduleCalculator.doseDates(
            on: day,
            schedule: schedule,
            calendar: calendar
        )

        let minutes = doses.map {
            calendar.component(.hour, from: $0) * 60
                + calendar.component(.minute, from: $0)
        }
        #expect(minutes == [30, 510, 990])
    }

    @Test("Linked time adjustment preserves intervals")
    func linkedAdjustment() {
        let shifted = ScheduleCalculator.shiftedLinkedTimes(
            [0, 480, 960],
            changing: 480,
            to: 510
        )

        #expect(shifted == [30, 510, 990])
    }

    @Test("As-needed schedule has no generated doses")
    func asNeededHasNoDoses() {
        let schedule = MedicationSchedule(
            daysOfWeek: [],
            times: [],
            startDate: .now,
            endDate: nil,
            leadTimeMinutes: 0
        )

        #expect(ScheduleCalculator.doseDates(
            for: schedule,
            after: .now,
            limit: 10,
            calendar: calendar
        ).isEmpty)
    }
}
