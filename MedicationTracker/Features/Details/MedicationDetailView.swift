import SwiftData
import SwiftUI

struct MedicationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager

    let medicine: Medicine
    var isReadOnly = false
    var onRestart: (() -> Void)?

    @State private var showingEdit = false
    @State private var pendingAction: MedicationDetailAction?

    var body: some View {
        VStack(spacing: 0) {
            SheetTitleBar(
                title: "Medication",
                onClose: { dismiss() },
                onEdit: isReadOnly ? nil : { showingEdit = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    dailyIntake

                    if !medicine.asNeeded {
                        weeklySchedule
                    }

                    duration

                    if let quantity = medicine.quantityRemaining {
                        quantityRemaining(quantity)
                    }

                    if isReadOnly, let onRestart {
                        FooterActionButton(
                            title: "Restart",
                            symbol: "arrow.clockwise",
                            foreground: .white,
                            background: AppTheme.blue,
                            action: onRestart
                        )
                    } else if !isReadOnly {
                        footer
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingEdit) {
            MedicineWizardView(medicine: medicine)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .alert(item: $pendingAction) { action in
            switch action {
            case .delete:
                Alert(
                    title: Text("Delete \(medicine.name)?"),
                    message: Text("This cannot be undone"),
                    primaryButton: .destructive(Text("Delete"), action: deleteMedicine),
                    secondaryButton: .cancel()
                )
            case .complete:
                Alert(
                    title: Text("Complete \(medicine.name)?"),
                    message: Text("This moves it to history"),
                    primaryButton: .default(Text("Complete"), action: completeMedicine),
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medicine.name)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.title)
            Text(medicine.strengthText)
                .font(.title3)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyIntake: some View {
        DetailLabelRow("Daily intake", symbol: "pill") {
            VStack(alignment: .leading, spacing: 8) {
                if medicine.asNeeded {
                    Text("As needed")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.blueFill)
                        .clipShape(.capsule)
                } else {
                    ForEach(medicine.sortedTimes, id: \.self) { minutes in
                        Text(minutes.medicationTime)
                            .font(.headline)
                    }
                }

                if let notes = medicine.notes {
                    Divider()
                    Label(notes, systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var weeklySchedule: some View {
        DetailLabelRow("Weekly schedule", symbol: "calendar") {
            DayCircles(selectedDays: Set(medicine.daysOfWeek))
        }
    }

    private var duration: some View {
        DetailLabelRow("Duration", symbol: "hourglass") {
            VStack(alignment: .leading, spacing: 10) {
                Label(medicine.startDate.shortMedicationDate, systemImage: "play.fill")
                if let endDate = medicine.endDate {
                    Label(endDate.shortMedicationDate, systemImage: "stop.fill")
                } else {
                    Label("∞", systemImage: "stop.fill")
                }
            }
            .font(.headline)
        }
    }

    private func quantityRemaining(_ quantity: Decimal) -> some View {
        DetailLabelRow("Quantity remaining", symbol: "shippingbox") {
            VStack(alignment: .leading, spacing: 5) {
                Text(quantity.medicationFormatted)
                    .font(.title3.bold())
                if let refillAt = medicine.refillAt {
                    Text("Running low at \(refillAt.medicationFormatted)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            FooterActionButton(
                title: "Delete",
                symbol: "trash",
                foreground: AppTheme.red,
                background: AppTheme.redFill
            ) {
                pendingAction = .delete
            }
            FooterActionButton(
                title: "Complete",
                symbol: "checkmark",
                foreground: AppTheme.green,
                background: AppTheme.greenFill
            ) {
                pendingAction = .complete
            }
        }
    }

    private func deleteMedicine() {
        let medicineID = medicine.id
        let plan = medicine.plan
        modelContext.delete(medicine)
        plan?.updateDates()
        try? modelContext.save()
        Task {
            await notificationManager.removeNotifications(forMedicineID: medicineID)
        }
        dismiss()
    }

    private func completeMedicine() {
        medicine.status = .completed
        medicine.completedAt = .now
        medicine.endDate = Date.now.startOfDay
        medicine.plan?.updateDates()
        try? modelContext.save()
        Task {
            await notificationManager.removeNotifications(for: medicine)
            await notificationManager.rebuildAll(context: modelContext)
        }
        dismiss()
    }
}

private enum MedicationDetailAction: String, Identifiable {
    case delete
    case complete

    var id: String { rawValue }
}
