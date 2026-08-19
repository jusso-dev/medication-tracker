import SwiftData
import SwiftUI

struct TreatmentPlanWizardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager
    @Query(sort: \Medicine.name) private var medicines: [Medicine]

    let onSaved: (TreatmentPlan) -> Void

    @State private var draft: TreatmentPlanDraft
    @State private var step = 0
    @State private var movingForward = true
    @State private var showingMedicineWizard = false
    @State private var saveError: String?

    private let titles = [
        "What is it treatment for?",
        "Add medicines to this plan",
        "Prescriber"
    ]

    init(
        plan: TreatmentPlan? = nil,
        onSaved: @escaping (TreatmentPlan) -> Void = { _ in }
    ) {
        self.onSaved = onSaved
        _draft = State(initialValue: TreatmentPlanDraft(plan: plan))
    }

    var body: some View {
        VStack(spacing: 0) {
            WizardNavigationBar(
                title: titles[step],
                step: step,
                totalSteps: titles.count,
                canContinue: canContinue,
                isLastStep: step == titles.count - 1,
                onBackOrClose: goBack,
                onContinue: continueTapped
            )

            ZStack {
                stepView
                    .id(step)
                    .transition(stepTransition)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: step)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingMedicineWizard) {
            MedicineWizardView { medicine in
                draft.selectedMedicineIDs.insert(medicine.id)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .alert("Couldn’t save treatment plan", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0:
            planNameStep
        case 1:
            medicineSelectionStep
        default:
            prescriberStep
        }
    }

    private var planNameStep: some View {
        VStack {
            Spacer(minLength: 40)
            TextField("e.g. Gastritis", text: $draft.title)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(AppTheme.title)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 18)
                .frame(minHeight: 72)
                .background(AppTheme.surface)
                .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .stroke(AppTheme.blueFillStrong, lineWidth: 2)
                }
                .accessibilityIdentifier("plan.title")
            Spacer()
        }
        .padding(20)
    }

    private var medicineSelectionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(draft.title)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.title)

                selectedDropZone

                SectionHeading(title: "All Medicines")

                if unselectedMedicines.isEmpty {
                    Text("No more medicines. Try adding a new one below")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(unselectedMedicines) { medicine in
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    draft.toggleMedicine(medicine)
                                }
                            } label: {
                                HStack {
                                    MedicineRowContent(medicine: medicine)
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(AppTheme.blue)
                                        .minimumTapTarget()
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(medicine.displayName) to this plan")
                            .accessibilityIdentifier("plan.add.\(medicine.name)")
                            if medicine.id != unselectedMedicines.last?.id {
                                Divider()
                            }
                        }
                    }
                    .medicationCard()
                }

                Button {
                    showingMedicineWizard = true
                } label: {
                    Label("+ Add new medicine", systemImage: "pill.badge.plus")
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.blueFill)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    private var selectedDropZone: some View {
        VStack(spacing: 0) {
            if selectedMedicines.isEmpty {
                Label("Add medicines to this plan", systemImage: "arrow.down.to.line")
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(selectedMedicines) { medicine in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            draft.toggleMedicine(medicine)
                        }
                    } label: {
                        HStack {
                            MedicineRowContent(medicine: medicine)
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppTheme.secondaryText)
                                .minimumTapTarget()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move \(medicine.displayName) back to All Medicines")
                    if medicine.id != selectedMedicines.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.blueFill.opacity(0.45))
        .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(
                    AppTheme.blue,
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                )
        }
    }

    private var prescriberStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)
            Text(draft.title)
                .font(.title.bold())
                .foregroundStyle(AppTheme.title)
            TextField("Self-managed", text: $draft.prescriber)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.title)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 18)
                .frame(minHeight: 70)
                .background(AppTheme.surface)
                .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .stroke(AppTheme.blueFillStrong, lineWidth: 2)
                }
                .accessibilityIdentifier("plan.prescriber")
            Text("Leave blank to use Self-managed.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .padding(20)
    }

    private var availableMedicines: [Medicine] {
        medicines.filter { medicine in
            guard medicine.status == .active else { return false }
            guard let assignedPlan = medicine.plan else { return true }
            return assignedPlan.id == draft.plan?.id
        }
    }

    private var selectedMedicines: [Medicine] {
        availableMedicines.filter { draft.selectedMedicineIDs.contains($0.id) }
    }

    private var unselectedMedicines: [Medicine] {
        availableMedicines.filter { !draft.selectedMedicineIDs.contains($0.id) }
    }

    private var canContinue: Bool {
        step == 0 ? draft.hasValidTitle : true
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return movingForward
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    private func goBack() {
        guard step > 0 else {
            dismiss()
            return
        }
        movingForward = false
        step -= 1
    }

    private func continueTapped() {
        guard canContinue else { return }
        guard step == titles.count - 1 else {
            movingForward = true
            step += 1
            return
        }

        do {
            let plan = try draft.save(context: modelContext, allMedicines: medicines)
            onSaved(plan)
            Task {
                await notificationManager.rebuildAll(context: modelContext)
            }
            dismiss()
        } catch {
            saveError = "Your changes could not be saved. Please try again."
        }
    }
}
