import SwiftUI

struct DurationStep: View {
    @Bindable var draft: MedicineDraft

    @State private var activeField: DurationDateField = .end
    @State private var displayedMonth: Date

    init(draft: MedicineDraft) {
        self.draft = draft
        _displayedMonth = State(initialValue: draft.startDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                dateCards

                Button {
                    draft.setOngoing()
                    activeField = .end
                } label: {
                    Label("Take indefinitely", systemImage: "infinity")
                        .font(.headline)
                        .foregroundStyle(draft.isOngoing ? .white : AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(draft.isOngoing ? AppTheme.title : AppTheme.blueFill)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("duration.take-indefinitely")
                .accessibilityValue(draft.isOngoing ? "Selected" : "")

                if !draft.isOngoing || activeField == .start {
                    MonthRangeCalendar(
                        displayedMonth: $displayedMonth,
                        startDate: draft.startDate,
                        endDate: draft.endDate,
                        onSelect: selectDate
                    )
                }

                if !draft.isOngoing {
                    Picker("Duration unit", selection: $draft.durationUnit) {
                        ForEach(DurationUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.durationUnit) {
                        if let endDate = draft.endDate {
                            draft.durationValue = ScheduleCalculator.durationValue(
                                from: draft.startDate,
                                to: endDate,
                                unit: draft.durationUnit
                            )
                        }
                    }

                    durationStepper
                }

                Text(durationExplanation)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
    }

    private var dateCards: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                startCard
                if !draft.isOngoing {
                    endCard
                }
            }
            VStack(spacing: 12) {
                startCard
                if !draft.isOngoing {
                    endCard
                }
            }
        }
    }

    private var startCard: some View {
        Button {
            activeField = .start
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.caption.weight(.semibold))
                Text(Calendar.current.isDateInToday(draft.startDate)
                     ? "Today"
                     : draft.startDate.shortMedicationDate)
                    .font(.headline)
            }
            .foregroundStyle(activeField == .start ? .white : AppTheme.title)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(.horizontal, 16)
            .background(activeField == .start ? AppTheme.blue : AppTheme.surface)
            .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        }
        .buttonStyle(.plain)
        .accessibilityValue(draft.startDate.longMedicationDate)
    }

    private var endCard: some View {
        HStack {
            Button {
                activeField = .end
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("End Date")
                        .font(.caption.weight(.semibold))
                    Text(endDateText)
                        .font(.headline)
                }
                .foregroundStyle(activeField == .end ? .white : AppTheme.title)
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                .padding(.leading, 16)
            }
            .buttonStyle(.plain)

            Button {
                activeField = .end
                draft.setOngoing()
            } label: {
                Text("∞")
                    .font(.title.bold())
                    .foregroundStyle(draft.isOngoing ? .white : AppTheme.blue)
                    .frame(width: 48, height: 48)
                    .background(draft.isOngoing ? AppTheme.title : AppTheme.blueFill)
                    .clipShape(.circle)
            }
            .accessibilityLabel("Ongoing, no end date")
            .accessibilityValue(draft.isOngoing ? "Selected" : "")
            .accessibilityIdentifier("duration.ongoing")
            .padding(.trailing, 10)
        }
        .background(activeField == .end ? AppTheme.blue : AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        .accessibilityElement(children: .contain)
    }

    private var durationStepper: some View {
        HStack {
            Button {
                changeDuration(by: -1)
            } label: {
                Image(systemName: "minus")
                    .font(.headline)
                    .minimumTapTarget()
                    .background(AppTheme.blueFill)
                    .clipShape(.circle)
            }
            .disabled(draft.durationValue == 0)
            .accessibilityLabel("Decrease duration")

            Spacer()

            Text("\(draft.durationValue)")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.title)
                .accessibilityLabel("\(draft.durationValue) \(draft.durationUnit.rawValue)")

            Spacer()

            Button {
                changeDuration(by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .minimumTapTarget()
                    .background(AppTheme.blue)
                    .clipShape(.circle)
            }
            .accessibilityLabel("Increase duration")
        }
        .padding(14)
        .background(AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            changeDuration(by: direction == .increment ? 1 : -1)
        }
    }

    private var endDateText: String {
        if draft.isOngoing {
            return "Ongoing"
        }
        return draft.endDate?.shortMedicationDate ?? "Selecting..."
    }

    private var durationExplanation: String {
        if draft.isOngoing {
            return "This medication has no planned end date."
        }
        guard let endDate = draft.endDate else {
            return "Choose an end date or tap Take indefinitely."
        }
        return "From \(draft.startDate.shortMedicationDate) to \(endDate.shortMedicationDate). Adding 7 Days ends seven calendar days after the start date."
    }

    private func changeDuration(by delta: Int) {
        draft.durationValue = max(0, draft.durationValue + delta)
        activeField = .end
        draft.isOngoing = false
        if draft.durationValue == 0 {
            draft.endDate = nil
        } else {
            draft.updateEndDateFromDuration()
        }
    }

    private func selectDate(_ date: Date) {
        switch activeField {
        case .start:
            draft.startDate = date.startOfDay
            if let endDate = draft.endDate, endDate < draft.startDate {
                draft.endDate = nil
                draft.durationValue = 0
            } else if let endDate = draft.endDate {
                draft.durationValue = ScheduleCalculator.durationValue(
                    from: draft.startDate,
                    to: endDate,
                    unit: draft.durationUnit
                )
            }
            activeField = draft.isOngoing ? .start : .end
        case .end:
            draft.setEndDate(date)
        }
    }
}

private enum DurationDateField {
    case start
    case end
}
