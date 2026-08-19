import SwiftData
import SwiftUI

struct MedicationsCatalogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \TreatmentPlan.title) private var plans: [TreatmentPlan]
    @Query(sort: \Medicine.name) private var medicines: [Medicine]

    @State private var addFlow: CatalogAddFlow?
    @State private var selectedPlan: TreatmentPlan?
    @State private var selectedMedicine: Medicine?
    @State private var editingPlan: TreatmentPlan?
    @State private var pendingPlanAction: PlanActionRequest?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                catalogHeader

                SectionHeading(title: "Treatment Plans")
                if activePlans.isEmpty {
                    EmptyActionCard(
                        symbol: "heart.text.clipboard",
                        title: "Create Treatment Plan",
                        subtitle: "Group medicines by condition, doctor, or goal"
                    ) {
                        addFlow = CatalogAddFlow(initialChoice: .treatmentPlan)
                    }
                } else {
                    ForEach(activePlans) { plan in
                        treatmentPlanCard(plan)
                    }
                }

                SectionHeading(title: "Individual Medicines")
                if individualMedicines.isEmpty {
                    EmptyActionCard(
                        symbol: "pill",
                        title: "Add Medicines",
                        subtitle: "Track daily, temporary, or as-needed medicines"
                    ) {
                        addFlow = CatalogAddFlow(initialChoice: .medicine)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(individualMedicines) { medicine in
                            Button {
                                selectedMedicine = medicine
                            } label: {
                                MedicineRowContent(medicine: medicine)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens medication details")

                            if medicine.id != individualMedicines.last?.id {
                                Divider()
                            }
                        }
                    }
                    .medicationCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $addFlow) { flow in
            AddNewFlowSheet(initialChoice: flow.initialChoice)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedPlan) { plan in
            TreatmentPlanDetailView(plan: plan)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedMedicine) { medicine in
            MedicationDetailView(medicine: medicine)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingPlan) { plan in
            TreatmentPlanWizardView(plan: plan)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .alert(item: $pendingPlanAction) { request in
            switch request.kind {
            case .ungroup:
                Alert(
                    title: Text("Ungroup \(request.plan.title)?"),
                    message: Text("Medicines stay in your catalog"),
                    primaryButton: .destructive(Text("Ungroup")) {
                        ungroup(request.plan)
                    },
                    secondaryButton: .cancel()
                )
            case .complete:
                Alert(
                    title: Text("Complete \(request.plan.title)?"),
                    message: Text("This moves it to history"),
                    primaryButton: .default(Text("Complete")) {
                        complete(request.plan)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var catalogHeader: some View {
        HStack {
            SheetIconButton(
                symbol: "clock.arrow.circlepath",
                label: "Past medications"
            ) {
                router.selectedTab = .history
            }

            Spacer()

            Text("Medications Catalog")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            SheetIconButton(symbol: "plus", label: "Add new") {
                addFlow = CatalogAddFlow(initialChoice: nil)
            }
        }
    }

    private func treatmentPlanCard(_ plan: TreatmentPlan) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.title)
                        Text(plan.prescriberDisplayName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens treatment plan details")
                .accessibilityIdentifier("plan.card.\(plan.title)")

                Menu {
                    Button("Edit", systemImage: "pencil") {
                        editingPlan = plan
                    }
                    Button("Ungroup", systemImage: "link.badge.minus") {
                        pendingPlanAction = PlanActionRequest(plan: plan, kind: .ungroup)
                    }
                    Button("Complete", systemImage: "checkmark.circle") {
                        pendingPlanAction = PlanActionRequest(plan: plan, kind: .complete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppTheme.title)
                        .minimumTapTarget()
                }
                .accessibilityLabel("More actions for \(plan.title)")
            }

            if plan.activeMedicines.isEmpty {
                Button {
                    selectedPlan = plan
                } label: {
                    Text("No medicines in this plan")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(plan.activeMedicines) { medicine in
                    Divider()
                    Button {
                        selectedMedicine = medicine
                    } label: {
                        MedicineRowContent(medicine: medicine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens medication details")
                }
            }
        }
        .medicationCard()
    }

    private var activePlans: [TreatmentPlan] {
        plans.filter { $0.status == .active }
    }

    private var individualMedicines: [Medicine] {
        medicines.filter { $0.status == .active && $0.plan == nil }
    }

    private func ungroup(_ plan: TreatmentPlan) {
        for medicine in plan.medicines {
            medicine.plan = nil
        }
        modelContext.delete(plan)
        try? modelContext.save()
    }

    private func complete(_ plan: TreatmentPlan) {
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
    }
}

private struct CatalogAddFlow: Identifiable {
    let id = UUID()
    let initialChoice: AddNewChoice?
}

private struct PlanActionRequest: Identifiable {
    enum Kind {
        case ungroup
        case complete
    }

    let id = UUID()
    let plan: TreatmentPlan
    let kind: Kind
}
