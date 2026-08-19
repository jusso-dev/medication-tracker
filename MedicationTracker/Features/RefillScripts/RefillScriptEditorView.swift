import SwiftData
import SwiftUI

struct RefillScriptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let medicine: Medicine
    let script: RefillScript?

    @State private var scriptNumber: String
    @State private var prescriber: String
    @State private var issuedDate: Date
    @State private var tracksIssuedDate: Bool
    @State private var expiryDate: Date
    @State private var tracksExpiry: Bool
    @State private var repeatsAuthorised: String
    @State private var repeatsRemaining: String
    @State private var notes: String
    @State private var showingScanner = false
    @State private var saveError: String?

    init(medicine: Medicine, script: RefillScript? = nil) {
        self.medicine = medicine
        self.script = script
        let defaultExpiry = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
        _scriptNumber = State(initialValue: script?.scriptNumber ?? "")
        _prescriber = State(initialValue: script?.prescriber ?? "")
        _issuedDate = State(initialValue: script?.issuedDate ?? .now)
        _tracksIssuedDate = State(initialValue: script?.issuedDate != nil)
        _expiryDate = State(initialValue: script?.expiryDate ?? defaultExpiry)
        _tracksExpiry = State(initialValue: script?.expiryDate != nil)
        _repeatsAuthorised = State(
            initialValue: script?.repeatsAuthorised.map(String.init) ?? ""
        )
        _repeatsRemaining = State(initialValue: String(script?.repeatsRemaining ?? 0))
        _notes = State(initialValue: script?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label(medicine.displayName, systemImage: "pills")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.title)

                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan prescription", systemImage: "text.viewfinder")
                            .font(.headline)
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppTheme.blueFill)
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)

                    fields
                    statusPreview

                    Text("Validity is based only on the expiry and repeats recorded here. Confirm dispensing eligibility with your pharmacist.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(script == nil ? "Add Refill Script" : "Review Refill Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            MedicationScanView(title: "Scan Prescription", onUse: applyScan)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .alert("Couldn’t save script", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var fields: some View {
        VStack(spacing: 16) {
            TextField("Script number (optional)", text: $scriptNumber)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)

            TextField("Prescriber (optional)", text: $prescriber)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Toggle("Record issue date", isOn: $tracksIssuedDate)
                .tint(AppTheme.blue)
            if tracksIssuedDate {
                DatePicker("Issued", selection: $issuedDate, displayedComponents: .date)
            }

            Toggle("Record expiry date", isOn: $tracksExpiry)
                .tint(AppTheme.blue)
            if tracksExpiry {
                DatePicker("Expires", selection: $expiryDate, displayedComponents: .date)
            }

            TextField("Repeats authorised (optional)", text: $repeatsAuthorised)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            TextField("Repeats remaining", text: $repeatsRemaining)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .medicationCard()
    }

    private var statusPreview: some View {
        HStack {
            CircularSymbol(
                name: statusSymbol,
                foreground: statusColour,
                background: statusColour.opacity(0.12)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Text("Preview—save to confirm this review")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .medicationCard()
    }

    private var previewStatus: RefillScriptStatus {
        let remaining = Int(repeatsRemaining) ?? 0
        if remaining <= 0 {
            return .noRepeats
        }
        guard tracksExpiry else {
            return .reviewNeeded
        }
        return expiryDate.startOfDay < Date.now.startOfDay ? .expired : .valid
    }

    private var statusTitle: String { previewStatus.title }

    private var statusSymbol: String {
        switch previewStatus {
        case .valid:
            "checkmark.seal.fill"
        case .expired:
            "calendar.badge.exclamationmark"
        case .noRepeats:
            "0.circle.fill"
        case .reviewNeeded:
            "questionmark.circle.fill"
        }
    }

    private var statusColour: Color {
        switch previewStatus {
        case .valid:
            AppTheme.green
        case .expired, .noRepeats:
            AppTheme.red
        case .reviewNeeded:
            AppTheme.blue
        }
    }

    private func applyScan(_ result: MedicationScanResult) {
        if let value = result.scriptNumber {
            scriptNumber = value
        }
        if let value = result.prescriber {
            prescriber = value
        }
        if let value = result.expiryDate {
            expiryDate = value
            tracksExpiry = true
        }
        if let value = result.repeatsAuthorised {
            repeatsAuthorised = String(value)
        }
        if let value = result.repeatsRemaining {
            repeatsRemaining = String(value)
        }
    }

    private func save() {
        guard let remaining = Int(repeatsRemaining), remaining >= 0 else {
            saveError = "Repeats remaining must be zero or a positive whole number."
            return
        }
        let authorisedText = repeatsAuthorised.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let authorised: Int?
        if authorisedText.isEmpty {
            authorised = nil
        } else if let value = Int(authorisedText), value >= 0 {
            authorised = value
        } else {
            saveError = "Repeats authorised must be zero or a positive whole number."
            return
        }
        if let authorised, remaining > authorised {
            saveError = "Repeats remaining can’t be greater than repeats authorised."
            return
        }

        if let script {
            script.scriptNumber = scriptNumber.nilIfBlank
            script.prescriber = prescriber.nilIfBlank
            script.issuedDate = tracksIssuedDate ? issuedDate.startOfDay : nil
            script.expiryDate = tracksExpiry ? expiryDate.startOfDay : nil
            script.repeatsAuthorised = authorised
            script.repeatsRemaining = remaining
            script.notes = notes.nilIfBlank
            script.lastReviewedAt = .now
        } else {
            let newScript = RefillScript(
                medicine: medicine,
                scriptNumber: scriptNumber,
                issuedDate: tracksIssuedDate ? issuedDate : nil,
                expiryDate: tracksExpiry ? expiryDate : nil,
                repeatsAuthorised: authorised,
                repeatsRemaining: remaining,
                prescriber: prescriber,
                lastReviewedAt: .now,
                notes: notes
            )
            modelContext.insert(newScript)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "The refill script could not be saved."
        }
    }
}
