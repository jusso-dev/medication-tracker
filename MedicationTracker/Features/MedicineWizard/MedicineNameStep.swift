import SwiftUI

struct MedicineNameStep: View {
    @Bindable var draft: MedicineDraft
    @FocusState private var nameIsFocused: Bool
    @State private var showingScanner = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 32)

                TextField("Medicine", text: $searchText)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
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
                    .onSubmit {
                        nameIsFocused = false
                    }

                medicineSuggestions

                Button {
                    nameIsFocused = false
                    showingScanner = true
                } label: {
                    Label("Scan medicine label", systemImage: "text.viewfinder")
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(AppTheme.blueFill)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)

                if !searchText.isEmpty {
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
        .onAppear {
            searchText = draft.name
            nameIsFocused = draft.name.isEmpty
        }
        .onChange(of: searchText) { _, value in
            draft.name = value
        }
        .sheet(isPresented: $showingScanner) {
            MedicationScanView(title: "Scan Medicine") { result in
                draft.applyScan(result)
                searchText = draft.name
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var medicineSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Australian medicine lookup")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Spacer()
                Text("Starter list")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            ForEach(suggestions) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.genericName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.title)
                    if !entry.commonBrands.isEmpty {
                        Text(entry.brandSummary)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            Picker(selection: $searchText) {
                if !suggestions.contains(where: { $0.genericName == searchText }) {
                    Text("Keep \(searchText)").tag(searchText)
                }
                ForEach(suggestions) { entry in
                    Text(entry.genericName).tag(entry.genericName)
                }
            } label: {
                Label("Use a listed medicine", systemImage: "list.bullet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppTheme.blueFill)
                    .clipShape(.capsule)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("medicine.lookup.menu")

            Text("Names only—confirm the medicine and strength against its label or with your pharmacist.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    private var suggestions: [AustralianMedicineEntry] {
        if searchText.isEmpty {
            let featured = [
                "Paracetamol", "Ibuprofen", "Amoxicillin",
                "Metformin", "Atorvastatin"
            ]
            return featured.compactMap { name in
                AustralianMedicineCatalogue.entries.first { $0.genericName == name }
            }
        }
        return AustralianMedicineCatalogue.search(searchText, limit: 6)
    }

}
