import SwiftUI

struct MedicineNameStep: View {
    @Bindable var draft: MedicineDraft
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                TextField("Medicine", text: $draft.name)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameIsFocused)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 72)
                    .background(AppTheme.surface)
                    .clipShape(.rect(cornerRadius: AppTheme.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                            .stroke(AppTheme.blueFillStrong, lineWidth: 2)
                    }
                    .accessibilityHint("Enter the medication, vitamin, or supplement name")
                    .accessibilityIdentifier("medicine.name")

                if !draft.name.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose a unit now, or on the next step")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(MedicineUnit.allCases.filter { $0 != .other }) { unit in
                                    Button(unit.displayName) {
                                        draft.unit = unit
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(draft.unit == unit ? .white : AppTheme.blue)
                                    .padding(.horizontal, 11)
                                    .frame(minHeight: 44)
                                    .background(draft.unit == unit ? AppTheme.blue : AppTheme.blueFill)
                                    .clipShape(.capsule)
                                    .accessibilityValue(draft.unit == unit ? "Selected" : "")
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { nameIsFocused = draft.name.isEmpty }
    }
}
