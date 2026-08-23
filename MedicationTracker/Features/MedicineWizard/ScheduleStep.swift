import SwiftUI
import UserNotifications

struct ScheduleStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NotificationManager.self) private var notificationManager
    @Bindable var draft: MedicineDraft
    @Binding var validationMessage: String?

    @AccessibilityFocusState private var validationIsFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(draft.contextLine)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.title)

                    validationCard
                    daysSection
                    timesSection
                    reminderToggle
                }
                .padding(20)
            }
            .onChange(of: draft.daysOfWeek) {
                refreshValidationMessage()
            }
            .onChange(of: draft.times) {
                refreshValidationMessage()
            }
            .onChange(of: validationMessage) { _, message in
                validationIsFocused = message != nil
                guard message != nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                        proxy.scrollTo("schedule-validation", anchor: .top)
                    }
                }
            }
        }
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Pick your days")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    draft.cycleDayPreset()
                } label: {
                    Label(draft.dayPreset ?? "Presets", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                }
                .minimumTapTarget()
            }

            DayCircles(selectedDays: draft.daysOfWeek) { day in
                draft.toggleDay(day)
            }

            HStack(spacing: 10) {
                Button {
                    draft.toggleAllDays()
                } label: {
                    Label(
                        draft.daysOfWeek == Set(1...7) ? "Clear days" : "Select all days",
                        systemImage: draft.daysOfWeek == Set(1...7)
                            ? "xmark.circle"
                            : "checkmark.circle"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppTheme.blueFill)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("schedule.all-days")

                Button {
                    draft.clearSchedule()
                } label: {
                    Text("As needed")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.surface)
                        .clipShape(.capsule)
                        .overlay {
                            Capsule().stroke(AppTheme.divider)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("schedule.as-needed")
            }
        }
        .medicationCard()
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pick your times")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    draft.cycleTimePreset()
                } label: {
                    HStack(spacing: 5) {
                        if draft.intervalLinked {
                            Image(systemName: "link")
                        }
                        Text(draft.timePreset ?? "Presets")
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .minimumTapTarget()
            }

            ForEach(draft.timeEntries) { entry in
                VStack(spacing: 8) {
                    HStack {
                        Button {
                            draft.removeTime(id: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(AppTheme.red)
                                .minimumTapTarget()
                        }
                        .accessibilityLabel("Delete \(currentMinutes(for: entry).medicationTime)")

                        Text(currentMinutes(for: entry).medicationTime)
                            .font(.headline)
                            .foregroundStyle(AppTheme.title)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .accessibilityIdentifier("schedule.time-label")
                    }

                    timeSlider(for: entry)
                }

                if entry.id != draft.timeEntries.last?.id {
                    Divider()
                }
            }

            Button {
                draft.addTime()
            } label: {
                Label("+ Add a Time", systemImage: "clock.badge.plus")
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.blueFill)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("schedule.add-time")
        }
        .medicationCard()
    }

    @ViewBuilder
    private var validationCard: some View {
        if let validationMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.red)
                    .accessibilityFocused($validationIsFocused)

                if !draft.daysOfWeek.isEmpty && draft.times.isEmpty {
                    Button("Add 8:00 a.m.", systemImage: "clock.badge.plus") {
                        draft.addTime()
                    }
                    .font(.subheadline.weight(.semibold))
                    .minimumTapTarget()
                } else if draft.daysOfWeek.isEmpty && !draft.times.isEmpty {
                    Button("Select all days", systemImage: "checkmark.circle") {
                        draft.toggleAllDays()
                    }
                    .font(.subheadline.weight(.semibold))
                    .minimumTapTarget()
                }

                Button("Use as needed instead") {
                    draft.clearSchedule()
                }
                .font(.subheadline.weight(.semibold))
                .minimumTapTarget()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.redFill)
            .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
            .accessibilityIdentifier("schedule.validation")
            .id("schedule-validation")
        }
    }

    private func refreshValidationMessage() {
        guard validationMessage != nil else { return }
        if draft.scheduleIsValid {
            validationMessage = nil
        } else {
            validationMessage = draft.daysOfWeek.isEmpty
                ? "Choose at least one day for the times you added."
                : "Add at least one time for the selected days."
        }
    }

    private var reminderToggle: some View {
        Toggle(isOn: reminderBinding) {
            Label("Remind me", systemImage: "bell")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
        }
        .tint(AppTheme.blue)
        .disabled(draft.isAsNeeded || !draft.scheduleIsValid)
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
        .accessibilityHint(
            draft.isAsNeeded ? "Add a schedule to turn on reminders" : "Uses local notifications"
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { draft.remindersOn },
            set: { newValue in
                guard newValue else {
                    draft.remindersOn = false
                    return
                }
                Task {
                    if notificationManager.authorizationStatus == .authorized
                        || notificationManager.authorizationStatus == .provisional {
                        draft.remindersOn = true
                    } else {
                        draft.remindersOn = await notificationManager.requestAuthorization()
                    }
                }
            }
        )
    }

    private func timeSlider(for entry: MedicineDraftTime) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(currentMinutes(for: entry)) },
                    set: { value in
                        let adjusted = min(
                            1_425,
                            max(0, Int((value / 15).rounded()) * 15)
                        )
                        _ = draft.updateTime(id: entry.id, to: adjusted)
                    }
                ),
                in: 0...1_425,
                step: 15
            )
            .tint(AppTheme.blue)
            .accessibilityElement()
            .accessibilityLabel("Time")
            .accessibilityValue(currentMinutes(for: entry).medicationTime)
            .accessibilityIdentifier("schedule.time-slider")

            HStack {
                Text("12 a.m.")
                Spacer()
                Text("Noon")
                Spacer()
                Text("11:45 p.m.")
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func currentMinutes(for entry: MedicineDraftTime) -> Int {
        draft.time(for: entry.id) ?? entry.minutes
    }
}
