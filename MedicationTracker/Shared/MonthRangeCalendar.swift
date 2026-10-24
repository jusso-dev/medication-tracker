import SwiftUI

struct MonthRangeCalendar: View {
    @Binding var displayedMonth: Date
    let startDate: Date
    let endDate: Date?
    let onSelect: (Date) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var cellSize: CGFloat = 44

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .minimumTapTarget()
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(displayedMonth.monthAndYear)
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .minimumTapTarget()
                }
                .accessibilityLabel("Next month")
            }

            ViewThatFits(in: .horizontal) {
                dayGrid
                ScrollView(.horizontal, showsIndicators: false) {
                    dayGrid
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 16)
        .background(AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
    }

    private var dayGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 7),
            spacing: 0
        ) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: cellSize, height: cellSize)
                    .accessibilityHidden(true)
            }

            ForEach(gridDays) { gridDay in
                switch gridDay.value {
                case .placeholder:
                    Color.clear.frame(width: cellSize, height: cellSize)
                case .date(let date):
                    dayButton(date)
                }
            }
        }
        .frame(width: cellSize * 7)
    }

    private var gridDays: [CalendarGridDay] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        var result = (0..<(firstWeekday - 1)).map {
            CalendarGridDay(id: "placeholder-\($0)", value: .placeholder)
        }
        result += range.compactMap { day -> CalendarGridDay? in
            guard let date = calendar.date(
                bySetting: .day,
                value: day,
                of: interval.start
            ) else {
                return nil
            }
            return CalendarGridDay(
                id: "day-\(Int(date.timeIntervalSinceReferenceDate / 86_400))",
                value: .date(date.startOfDay)
            )
        }
        return result
    }

    private func dayButton(_ date: Date) -> some View {
        let isStart = calendar.isDate(date, inSameDayAs: startDate)
        let isEnd = endDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isInRange = endDate.map {
            date.startOfDay >= startDate.startOfDay && date.startOfDay <= $0.startOfDay
        } ?? false

        return Button {
            onSelect(date)
        } label: {
            Text(date.formatted(.dateTime.day()))
                .font(.subheadline.weight(isStart || isEnd ? .bold : .regular))
                .foregroundStyle(isStart || isEnd ? .white : AppTheme.text)
                .frame(width: cellSize, height: cellSize)
                .background(
                    isStart || isEnd
                        ? AppTheme.blue
                        : (isInRange ? AppTheme.blueFillStrong : .clear)
                )
                .clipShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.longMedicationDate)
        .accessibilityValue(
            isStart ? "Start date" : (isEnd ? "End date" : (isInRange ? "In selected range" : ""))
        )
    }

    private func moveMonth(by value: Int) {
        displayedMonth = calendar.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) ?? displayedMonth
    }
}

private struct CalendarGridDay: Identifiable {
    enum Value {
        case placeholder
        case date(Date)
    }

    let id: String
    let value: Value
}
