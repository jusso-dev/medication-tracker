import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \Medicine.name) private var medicines: [Medicine]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        Text(timeline.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)

                        let doses = scheduledDoses(on: timeline.date)
                        doseSection(
                            "Due now",
                            doses: doses.filter { $0.category(at: timeline.date) == .due },
                            kind: .due
                        )
                        doseSection(
                            "Later today",
                            doses: doses.filter { $0.category(at: timeline.date) == .later },
                            kind: .later
                        )
                        doseSection(
                            "Missed",
                            doses: doses.filter { $0.category(at: timeline.date) == .missed },
                            kind: .missed
                        )
                        doseSection(
                            "Taken",
                            doses: doses.filter { $0.category(at: timeline.date) == .taken },
                            kind: .taken
                        )
                        doseSection(
                            "Skipped",
                            doses: doses.filter { $0.category(at: timeline.date) == .skipped },
                            kind: .skipped
                        )

                        asNeededSection

                        if doses.isEmpty && asNeededMedicines.isEmpty {
                            ContentUnavailableView(
                                "No doses today",
                                systemImage: "checkmark.circle",
                                description: Text("Scheduled and as-needed medicines appear here.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 240)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .task(id: router.highlightedDoseID) {
                    guard let id = router.highlightedDoseID else { return }
                    await Task.yield()
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Today")
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func doseSection(
        _ title: String,
        doses: [ScheduledDose],
        kind: TodayDoseCategory
    ) -> some View {
        if !doses.isEmpty {
            SectionHeading(title: title)
            VStack(spacing: 0) {
                ForEach(doses) { dose in
                    doseRow(dose, kind: kind)
                        .id(dose.id)
                    if dose.id != doses.last?.id {
                        Divider()
                    }
                }
            }
            .medicationCard()
        }
    }

    private func doseRow(
        _ dose: ScheduledDose,
        kind: TodayDoseCategory
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dose.medicine.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.title)
                    Text(dose.medicine.strengthText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text(dose.scheduledAt.medicationTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            }

            switch kind {
            case .due:
                HStack {
                    compactAction("Take", color: AppTheme.green) {
                        record(dose, outcome: .taken)
                    }
                    compactAction("Skip", color: AppTheme.red) {
                        record(dose, outcome: .skipped)
                    }
                    if !dose.hasBeenSnoozed {
                        compactAction("Snooze", color: AppTheme.blue) {
                            Task {
                                await notificationManager.snooze(
                                    medicineID: dose.medicine.id,
                                    scheduledAt: dose.originalScheduledAt
                                )
                            }
                        }
                    }
                }
            case .later:
                Label("Scheduled", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            case .missed:
                HStack {
                    compactAction("Take late", color: AppTheme.green) {
                        record(dose, outcome: .late)
                    }
                    compactAction("Skip", color: AppTheme.red) {
                        record(dose, outcome: .skipped)
                    }
                }
            case .taken, .skipped:
                Label(
                    dose.event?.outcome.displayName ?? kind.title,
                    systemImage: kind == .taken ? "checkmark.circle.fill" : "forward.end.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kind == .taken ? AppTheme.green : AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 8)
        .overlay {
            if router.highlightedDoseID == dose.id {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.blue, lineWidth: 2)
                    .padding(-6)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var asNeededSection: some View {
        if !asNeededMedicines.isEmpty {
            SectionHeading(title: "As needed")
            VStack(spacing: 0) {
                ForEach(asNeededMedicines) { medicine in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(medicine.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.title)
                            Text(medicine.strengthText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        let canLog = DoseService.canLogAsNeeded(medicine: medicine)
                        Button(canLog ? "Log dose" : "Daily limit reached") {
                            guard canLog else { return }
                            recordAsNeeded(medicine)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(canLog ? .white : AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(canLog ? AppTheme.blue : AppTheme.divider)
                        .clipShape(.capsule)
                        .disabled(!canLog)
                    }
                    .padding(.vertical, 8)
                    .id(medicine.id.uuidString)
                    if medicine.id != asNeededMedicines.last?.id {
                        Divider()
                    }
                }
            }
            .medicationCard()
        }
    }

    private var activeMedicines: [Medicine] {
        medicines.filter { medicine in
            medicine.status == .active
                && medicine.startDate.startOfDay <= Date.now.startOfDay
                && (medicine.endDate.map { $0.startOfDay >= Date.now.startOfDay } ?? true)
        }
    }

    private var asNeededMedicines: [Medicine] {
        activeMedicines.filter(\.asNeeded)
    }

    private func scheduledDoses(on day: Date) -> [ScheduledDose] {
        activeMedicines
            .filter { !$0.asNeeded }
            .flatMap { medicine -> [ScheduledDose] in
                let schedule = MedicationSchedule(
                    daysOfWeek: medicine.daysOfWeek,
                    times: medicine.times,
                    startDate: medicine.startDate,
                    endDate: medicine.endDate,
                    leadTimeMinutes: 0
                )
                return ScheduleCalculator.doseDates(on: day, schedule: schedule).map { scheduledAt in
                    let event = DoseService.event(for: medicine, scheduledAt: scheduledAt)
                    let snooze = DoseService.snoozedEvent(for: medicine, scheduledAt: scheduledAt)
                    return ScheduledDose(
                        medicine: medicine,
                        scheduledAt: snooze?.takenAt ?? scheduledAt,
                        originalScheduledAt: scheduledAt,
                        event: event,
                        hasBeenSnoozed: snooze != nil
                    )
                }
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func compactAction(
        _ title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .frame(minHeight: 44)
            .background(color.opacity(0.12))
            .clipShape(.capsule)
    }

    private func record(_ dose: ScheduledDose, outcome: DoseOutcome) {
        do {
            let actualOutcome: DoseOutcome = outcome == .taken
                && Date.now > dose.scheduledAt.addingTimeInterval(60)
                ? .late
                : outcome
            let lowStock = try DoseService.record(
                medicine: dose.medicine,
                outcome: actualOutcome,
                scheduledAt: dose.originalScheduledAt,
                context: modelContext
            )
            if lowStock {
                Task {
                    _ = await notificationManager.scheduleLowStockNotification(for: dose.medicine)
                }
            }
            Task {
                await notificationManager.removeDoseNotification(
                    medicineID: dose.medicine.id,
                    scheduledAt: dose.originalScheduledAt
                )
            }
        } catch {
            return
        }
    }

    private func recordAsNeeded(_ medicine: Medicine) {
        do {
            let lowStock = try DoseService.record(
                medicine: medicine,
                outcome: .loggedAsNeeded,
                context: modelContext
            )
            if lowStock {
                Task {
                    _ = await notificationManager.scheduleLowStockNotification(for: medicine)
                }
            }
        } catch {
            return
        }
    }
}

private struct ScheduledDose: Identifiable {
    let medicine: Medicine
    let scheduledAt: Date
    let originalScheduledAt: Date
    let event: DoseEvent?
    let hasBeenSnoozed: Bool

    var id: String {
        "\(medicine.id.uuidString)-\(originalScheduledAt.timeIntervalSince1970)"
    }

    func category(at now: Date) -> TodayDoseCategory {
        if let event {
            return event.outcome == .skipped ? .skipped : .taken
        }
        if scheduledAt < now.addingTimeInterval(-5 * 60) {
            return .missed
        }
        if scheduledAt <= now {
            return .due
        }
        return .later
    }
}

private enum TodayDoseCategory {
    case due
    case later
    case missed
    case taken
    case skipped

    var title: String {
        switch self {
        case .due:
            "Due now"
        case .later:
            "Later today"
        case .missed:
            "Missed"
        case .taken:
            "Taken"
        case .skipped:
            "Skipped"
        }
    }
}
