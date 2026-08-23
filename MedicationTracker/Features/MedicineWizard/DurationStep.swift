import SwiftUI

struct DurationStep: View {
    @Bindable var draft: MedicineDraft

    @State private var activeField: DurationDateField
    @State private var displayedMonth: Date

    init(draft: MedicineDraft) {
        self.draft = draft
        _activeField = State(initialValue: draft.isOngoing ? .start : .end)
        _displayedMonth = State(initialValue: draft.startDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                dateCards
                ongoingToggle

                MonthRangeCalendar(
                    displayedMonth: $displayedMonth,
                    startDate: draft.startDate,
                    endDate: draft.endDate,
                    onSelect: selectDate
                )

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
                endCard
            }
            VStack(spacing: 12) {
                startCard
                endCard
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

    @ViewBuilder
    private var endCard: some View {
        if draft.isOngoing {
            VStack(alignment: .leading, spacing: 8) {
                Text("End Date")
                    .font(.caption.weight(.semibold))
                Label("No end date", systemImage: "infinity")
                    .font(.headline)
            }
            .foregroundStyle(AppTheme.title)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(.horizontal, 16)
            .background(AppTheme.surface)
            .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
            .accessibilityElement(children: .combine)
        } else {
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
                .padding(.horizontal, 16)
                .background(activeField == .end ? AppTheme.blue : AppTheme.surface)
                .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
        }
    }

    private var ongoingToggle: some View {
        Toggle(isOn: ongoingBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Take indefinitely", systemImage: "infinity")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Text("Keep this medication active with no planned end date.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .tint(AppTheme.blue)
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        .accessibilityIdentifier("duration.ongoing")
    }

    private var ongoingBinding: Binding<Bool> {
        Binding(
            get: { draft.isOngoing },
            set: { isOngoing in
                if isOngoing {
                    activeField = .start
                    draft.setOngoing()
                } else {
                    activeField = .end
                    draft.isOngoing = false
                    draft.durationValue = max(1, draft.durationValue)
                    draft.updateEndDateFromDuration()
                }
            }
        )
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
            return "Choose an end date or turn on Take indefinitely for an ongoing medication."
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
            activeField = .end
        case .end:
            draft.setEndDate(date)
        }
    }
}

private enum DurationDateField {
    case start
    case end
}
