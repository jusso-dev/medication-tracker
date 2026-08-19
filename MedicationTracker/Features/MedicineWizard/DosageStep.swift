import SwiftUI

struct DosageStep: View {
    @Bindable var draft: MedicineDraft
    @Binding var showAmountTooltip: Bool

    private let fractions = ["½", "⅓", "¼", "¾"]
    private let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(draft.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppTheme.title)
                    Text(amountSummary)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(draft.hasValidAmount ? AppTheme.blue : AppTheme.secondaryText)
                        .accessibilityLabel("Dose \(amountSummary)")
                        .accessibilityIdentifier("dose.amount")
                }

                unitTabs

                if showAmountTooltip && !draft.hasValidAmount {
                    Label("Please provide the amount", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.title)
                        .padding(12)
                        .background(AppTheme.blueFill)
                        .clipShape(.rect(cornerRadius: 14))
                        .transition(.opacity)
                }

                customKeypad
                optionalDetails
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft.amountText) {
            if draft.hasValidAmount {
                showAmountTooltip = false
            }
        }
        .onChange(of: draft.packageExpiryEnabled) { _, enabled in
            if enabled && draft.packageExpiryDate == nil {
                draft.packageExpiryDate = Calendar.current.date(
                    byAdding: .year,
                    value: 1,
                    to: .now
                )?.startOfDay
            }
        }
    }

    private var amountSummary: String {
        guard !draft.amountText.isEmpty else {
            return "Amount \(draft.unit.displayName)"
        }
        return "\(draft.amountText) \(draft.unit.displayName)"
    }

    private var unitTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(MedicineUnit.allCases.filter { $0 != .other }) { unit in
                    Button(unit.displayName) {
                        draft.unit = unit
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(draft.unit == unit ? AppTheme.blue : AppTheme.secondaryText)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(draft.unit == unit ? AppTheme.blue : .clear)
                            .frame(height: 2)
                    }
                    .minimumTapTarget()
                    .accessibilityValue(draft.unit == unit ? "Selected" : "")
                    .accessibilityIdentifier("dose.unit.\(unit.rawValue)")
                }
            }
        }
    }

    private var customKeypad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(fractions, id: \.self) { fraction in
                    keypadButton(fraction) {
                        draft.amountText = fraction
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(digits, id: \.self) { digit in
                    keypadButton(digit) {
                        if fractions.contains(draft.amountText) {
                            draft.amountText = digit
                        } else {
                            draft.amountText.append(digit)
                        }
                    }
                }

                keypadButton("0") {
                    if draft.amountText != "0" {
                        draft.amountText.append("0")
                    }
                }
                .gridCellColumns(2)

                Button {
                    if !draft.amountText.isEmpty {
                        draft.amountText.removeLast()
                    }
                } label: {
                    Image(systemName: "xmark.hexagon.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppTheme.red)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete last digit")
            }

            Button {
                draft.amountText = ""
                showAmountTooltip = false
            } label: {
                Label("Clear dose", systemImage: "eraser")
                    .font(.headline)
                    .foregroundStyle(AppTheme.red)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.redFill)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(draft.amountText.isEmpty)
            .accessibilityIdentifier("dose.clear")
        }
    }

    private var optionalDetails: some View {
        DisclosureGroup {
            VStack(spacing: 14) {
                TextField("Notes / take-with (optional)", text: $draft.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityHint("For example, With food or Before bed")

                Toggle("Track package expiry", isOn: $draft.packageExpiryEnabled)
                    .tint(AppTheme.blue)

                if draft.packageExpiryEnabled {
                    DatePicker(
                        "Package expiry",
                        selection: Binding(
                            get: {
                                draft.packageExpiryDate
                                    ?? Calendar.current.date(
                                        byAdding: .year,
                                        value: 1,
                                        to: .now
                                    )
                                    ?? .now
                            },
                            set: { draft.packageExpiryDate = $0.startOfDay }
                        ),
                        displayedComponents: .date
                    )
                }

                TextField("As-needed daily cap (optional)", text: $draft.dailyCapText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Quantity remaining (optional)", text: $draft.quantityText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                if !draft.quantityText.isEmpty {
                    TextField("Refill threshold", text: $draft.refillAtText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.top, 12)
        } label: {
            Label("Optional details", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
        }
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
    }

    private func keypadButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.title)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppTheme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .buttonStyle(.plain)
            .accessibilityIdentifier("dose.key.\(title)")
    }
}
