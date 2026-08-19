import SwiftUI

enum AddNewChoice {
    case medicine
    case treatmentPlan
}

struct AddNewFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var choice: AddNewChoice?

    init(initialChoice: AddNewChoice? = nil) {
        _choice = State(initialValue: initialChoice)
    }

    var body: some View {
        Group {
            switch choice {
            case .none:
                chooser
            case .medicine:
                MedicineWizardView()
            case .treatmentPlan:
                TreatmentPlanWizardView()
            }
        }
        .background(AppTheme.background)
    }

    private var chooser: some View {
        VStack(spacing: 22) {
            HStack {
                Color.clear.frame(width: 44, height: 44)
                Spacer()
                Text("Add new")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SheetIconButton(symbol: "xmark", label: "Close") {
                    dismiss()
                }
            }

            VStack(spacing: 16) {
                chooserCard(
                    symbol: "pill",
                    title: "Medicine",
                    subtitle: "Track daily, temporary, or as-needed medicines."
                ) {
                    choice = .medicine
                }

                chooserCard(
                    symbol: "heart.text.clipboard",
                    title: "Treatment Plan",
                    subtitle: "Group medicines by condition, doctor, or goal."
                ) {
                    choice = .treatmentPlan
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func chooserCard(
        symbol: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    CircularSymbol(name: symbol, size: 58)
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.blue)
                        .clipShape(.circle)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.title)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.blue)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .medicationCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("add.choice.\(title)")
    }
}
