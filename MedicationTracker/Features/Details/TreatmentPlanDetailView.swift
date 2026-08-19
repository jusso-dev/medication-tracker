import SwiftData
import SwiftUI

struct TreatmentPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager

    let plan: TreatmentPlan

    @State private var showingEdit = false
    @State private var selectedMedicine: Medicine?
    @State private var pendingAction: TreatmentPlanDetailAction?

    var body: some View {
        VStack(spacing: 0) {
            SheetTitleBar(
                title: "Treatment plan",
                onClose: { dismiss() },
                onEdit: { showingEdit = true }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(plan.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.title)

                    DetailLabelRow("Prescribed by", symbol: "doc.text") {
                        Text(plan.prescriberDisplayName)
                            .font(.headline)
                    }

                    DetailLabelRow("End date", symbol: "calendar") {
                        Text(endDateText)
                            .font(.headline)
                    }

                    SectionHeading(title: "Medications")

                    if plan.activeMedicines.isEmpty {
                        Text("No medicines in this plan")
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 90)
                            .medicationCard()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(plan.activeMedicines) { medicine in
                                Button {
                                    selectedMedicine = medicine
                                } label: {
                                    MedicineRowContent(medicine: medicine)
                                        .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens medication details")

                                if medicine.id != plan.activeMedicines.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .medicationCard()
                    }

                    footer
                }
                .padding(20)
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingEdit) {
            TreatmentPlanWizardView(plan: plan)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedMedicine) { medicine in
            MedicationDetailView(medicine: medicine)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .alert(item: $pendingAction) { action in
            switch action {
            case .ungroup:
                Alert(
                    title: Text("Ungroup \(plan.title)?"),
                    message: Text("Medicines stay in your catalog"),
                    primaryButton: .destructive(Text("Ungroup"), action: ungroup),
                    secondaryButton: .cancel()
                )
            case .complete:
                Alert(
                    title: Text("Complete \(plan.title)?"),
                    message: Text("This moves it to history"),
                    primaryButton: .default(Text("Complete"), action: complete),
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var endDateText: String {
        if let endDate = plan.endDate {
            return endDate.longMedicationDate
        }
        return plan.activeMedicines.contains(where: { $0.endDate == nil }) ? "∞" : "Not set"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            FooterActionButton(
                title: "Ungroup",
                symbol: "link.badge.minus",
                foreground: AppTheme.red,
                background: AppTheme.redFill
            ) {
                pendingAction = .ungroup
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

    private func ungroup() {
        for medicine in plan.medicines {
            medicine.plan = nil
        }
        modelContext.delete(plan)
        try? modelContext.save()
        dismiss()
    }

    private func complete() {
        let today = Date.now.startOfDay
        plan.status = .completed
        plan.completedAt = .now
        plan.endDate = today
        for medicine in plan.medicines where medicine.status == .active {
            medicine.status = .completed
            medicine.completedAt = .now
            medicine.endDate = today
        }
        try? modelContext.save()
        Task {
            for medicine in plan.medicines {
                await notificationManager.removeNotifications(forMedicineID: medicine.id)
            }
            await notificationManager.rebuildAll(context: modelContext)
        }
        dismiss()
    }
}

private enum TreatmentPlanDetailAction: String, Identifiable {
    case ungroup
    case complete

    var id: String { rawValue }
}
