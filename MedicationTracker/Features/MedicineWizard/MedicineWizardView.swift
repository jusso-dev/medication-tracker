import SwiftData
import SwiftUI
import UserNotifications

struct MedicineWizardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notificationManager

    let plan: TreatmentPlan?
    let onSaved: (Medicine) -> Void

    @State private var draft: MedicineDraft
    @State private var step = 0
    @State private var movingForward = true
    @State private var showAmountTooltip = false
    @State private var scheduleValidationMessage: String?
    @State private var saveError: String?

    private let titles = [
        "Enter medicine name",
        "Set your dosage",
        "Any schedule?",
        "How long will you take it?"
    ]

    init(
        medicine: Medicine? = nil,
        plan: TreatmentPlan? = nil,
        onSaved: @escaping (Medicine) -> Void = { _ in }
    ) {
        self.plan = plan
        self.onSaved = onSaved
        _draft = State(initialValue: MedicineDraft(medicine: medicine))
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
        .alert("Couldn’t save medication", isPresented: Binding(
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
            MedicineNameStep(draft: draft)
        case 1:
            DosageStep(draft: draft, showAmountTooltip: $showAmountTooltip)
        case 2:
            ScheduleStep(
                draft: draft,
                validationMessage: $scheduleValidationMessage
            )
        default:
            DurationStep(draft: draft)
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0:
            draft.hasValidName
        case 1:
            draft.hasValidAmount
        case 2:
            draft.scheduleIsValid
        default:
            draft.durationIsValid
        }
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
        scheduleValidationMessage = nil
        step -= 1
    }

    private func continueTapped() {
        guard canContinue else {
            if step == 1 {
                showAmountTooltip = true
            } else if step == 2 {
                scheduleValidationMessage = draft.daysOfWeek.isEmpty
                    ? "Choose at least one day for the times you added."
                    : "Add at least one time for the selected days."
            }
            return
        }

        guard step == titles.count - 1 else {
            movingForward = true
            scheduleValidationMessage = nil
            step += 1
            return
        }

        do {
            let medicine = try draft.save(context: modelContext, plan: plan)
            onSaved(medicine)
            Task {
                if medicine.quantityRemaining != nil
                    && notificationManager.authorizationStatus == .notDetermined {
                    _ = await notificationManager.requestAuthorization()
                }
                await notificationManager.rebuildAll(context: modelContext)
            }
            dismiss()
        } catch {
            saveError = "Your changes could not be saved. Please try again."
        }
    }
}
