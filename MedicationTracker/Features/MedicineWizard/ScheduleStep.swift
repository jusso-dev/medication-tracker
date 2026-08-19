import SwiftUI
import UserNotifications

struct ScheduleStep: View {
    @Environment(NotificationManager.self) private var notificationManager
    @Bindable var draft: MedicineDraft

    @State private var expandedTime: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(draft.contextLine)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.title)

                daysSection
                timesSection
                reminderToggle

                if !draft.scheduleIsValid {
                    Label(
                        "Choose at least one day and one time, or leave both empty for as-needed.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(20)
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        draft.cycleTimePreset()
                        expandedTime = nil
                    }
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

            ForEach(draft.times, id: \.self) { minutes in
                VStack(spacing: 8) {
                    HStack {
                        Button {
                            draft.removeTime(minutes)
                            if expandedTime == minutes {
                                expandedTime = nil
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(AppTheme.red)
                                .minimumTapTarget()
                        }
                        .accessibilityLabel("Delete \(minutes.medicationTime)")

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedTime = expandedTime == minutes ? nil : minutes
                            }
                        } label: {
                            HStack {
                                Text(minutes.medicationTime)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.title)
                                Spacer()
                                Image(systemName: expandedTime == minutes ? "chevron.up" : "chevron.right")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Adjust \(minutes.medicationTime)")
                        .accessibilityValue(expandedTime == minutes ? "Expanded" : "Collapsed")
                    }

                    if expandedTime == minutes {
                        timeSlider(for: minutes)
                            .transition(.opacity)
                    }
                }

                if minutes != draft.times.last {
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
        }
        .medicationCard()
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

    private func timeSlider(for minutes: Int) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(expandedTime ?? minutes) },
                    set: { value in
                        let adjusted = min(1_435, max(0, Int(value / 15) * 15))
                        let oldValue = expandedTime ?? minutes
                        if draft.updateTime(from: oldValue, to: adjusted) {
                            expandedTime = adjusted
                        }
                    }
                ),
                in: 0...1_435,
                step: 15
            )
            .tint(AppTheme.blue)
            .accessibilityLabel("Time")
            .accessibilityValue((expandedTime ?? minutes).medicationTime)

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
}
