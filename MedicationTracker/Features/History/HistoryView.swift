import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \Medicine.completedAt, order: .reverse) private var medicines: [Medicine]

    @State private var selectedMedicine: Medicine?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("Past medications")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                if completedMedicines.isEmpty {
                    ContentUnavailableView(
                        "No past medications",
                        systemImage: "clock",
                        description: Text("Completed medications will be kept here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(monthGroups) { group in
                        SectionHeading(title: group.month.monthAndYear)
                        VStack(spacing: 0) {
                            ForEach(group.medicines) { medicine in
                                Button {
                                    selectedMedicine = medicine
                                } label: {
                                    historyRow(medicine)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens read-only medication details")

                                if medicine.id != group.medicines.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .medicationCard()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedMedicine) { medicine in
            MedicationDetailView(
                medicine: medicine,
                isReadOnly: true,
                onRestart: {
                    restart(medicine)
                    selectedMedicine = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var completedMedicines: [Medicine] {
        medicines.filter { $0.status == .completed }
    }

    private var monthGroups: [HistoryMonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: completedMedicines) { medicine in
            let date = medicine.completedAt ?? medicine.endDate ?? medicine.startDate
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date.startOfDay
        }
        return grouped
            .map { HistoryMonthGroup(month: $0.key, medicines: $0.value) }
            .sorted { $0.month > $1.month }
    }

    private func historyRow(_ medicine: Medicine) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(medicine.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.title)
                    Text(medicine.strengthText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text("Completed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(AppTheme.greenFill)
                    .clipShape(.capsule)
            }

            if let plan = medicine.plan {
                Label(plan.title, systemImage: "heart.text.clipboard")
                    .font(.caption)
                    .foregroundStyle(AppTheme.blue)
            }

            Text(dateRange(for: medicine))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func dateRange(for medicine: Medicine) -> String {
        let end = medicine.endDate?.shortMedicationDate ?? "∞"
        return "\(medicine.startDate.shortMedicationDate) – \(end)"
    }

    private func restart(_ medicine: Medicine) {
        let calendar = Calendar.current
        let oldEnd = medicine.endDate
        let duration = oldEnd.map {
            calendar.dateComponents(
                [.day],
                from: medicine.startDate.startOfDay,
                to: $0.startOfDay
            ).day ?? 0
        }
        let newEnd = duration.flatMap {
            calendar.date(byAdding: .day, value: max(0, $0), to: Date.now.startOfDay)
        }

        let clone = Medicine(
            name: medicine.name,
            amount: medicine.amount,
            unit: medicine.unit,
            asNeeded: medicine.asNeeded,
            daysOfWeek: medicine.daysOfWeek,
            times: medicine.times,
            intervalMinutes: medicine.intervalMinutes,
            intervalLinked: medicine.intervalLinked,
            startDate: .now,
            endDate: newEnd,
            remindersOn: medicine.remindersOn,
            notes: medicine.notes,
            dailyCap: medicine.dailyCap,
            quantityRemaining: medicine.quantityRemaining,
            refillAt: medicine.refillAt
        )
        modelContext.insert(clone)
        try? modelContext.save()
        router.selectedTab = .medications
        Task {
            await notificationManager.rebuildAll(context: modelContext)
        }
    }
}

private struct HistoryMonthGroup: Identifiable {
    let month: Date
    let medicines: [Medicine]

    var id: Date { month }
}
