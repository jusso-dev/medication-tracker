import SwiftUI

struct WizardNavigationBar: View {
    let title: String
    let step: Int
    let totalSteps: Int
    let canContinue: Bool
    let isLastStep: Bool
    let onBackOrClose: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SheetIconButton(
                    symbol: step == 0 ? "xmark" : "chevron.left",
                    label: step == 0 ? "Close" : "Previous step",
                    action: onBackOrClose
                )

                Spacer()

                Text("\(step + 1) of \(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityLabel("Step \(step + 1) of \(totalSteps)")

                Spacer()

                Button(action: onContinue) {
                    Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                        .font(.body.weight(.bold))
                        .foregroundStyle(canContinue ? .white : AppTheme.secondaryText)
                        .minimumTapTarget()
                        .background(canContinue ? AppTheme.blue : AppTheme.divider)
                        .clipShape(.circle)
                }
                .accessibilityLabel(isLastStep ? "Save" : "Next step")
                .accessibilityValue(canContinue ? "Available" : "Complete this step first")
                .accessibilityIdentifier(isLastStep ? "wizard.save" : "wizard.next")
            }

            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

struct SheetTitleBar: View {
    let title: String
    let onClose: () -> Void
    var onEdit: (() -> Void)?

    var body: some View {
        HStack {
            SheetIconButton(symbol: "xmark", label: "Close", action: onClose)

            Spacer()

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.title)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let onEdit {
                SheetIconButton(symbol: "pencil", label: "Edit", action: onEdit)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}
