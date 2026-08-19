import SwiftData
import SwiftUI

struct RefillScriptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let script: RefillScript
    let allowsEditing: Bool

    @State private var showingEditor = false
    @State private var pendingAction: ScriptAction?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusCard
                    details

                    Text("This status is a personal record based on the entered expiry and repeat count. A pharmacist must confirm whether a prescription can be dispensed.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)

                    if allowsEditing {
                        actions
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Refill Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("refill.review.close")
                }
                if allowsEditing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEditor = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let medicine = script.medicine {
                RefillScriptEditorView(medicine: medicine, script: script)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .alert(item: $pendingAction) { action in
            switch action {
            case .recordRefill:
                Alert(
                    title: Text("Record one refill?"),
                    message: Text("This reduces repeats remaining by one."),
                    primaryButton: .default(Text("Record")) {
                        recordRefill()
                    },
                    secondaryButton: .cancel()
                )
            case .delete:
                Alert(
                    title: Text("Delete this refill script?"),
                    message: Text("This cannot be undone"),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteScript()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert("Couldn’t update refill script", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            CircularSymbol(
                name: statusSymbol,
                foreground: statusColour,
                background: statusColour.opacity(0.12),
                size: 54
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(script.status.title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.title)
                Text("\(script.repeatsRemaining) repeats remaining")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .medicationCard()
    }

    private var details: some View {
        VStack(spacing: 14) {
            detailRow("Medicine", script.medicine?.displayName)
            detailRow("Script number", script.scriptNumber)
            detailRow("Prescriber", script.prescriber)
            detailRow("Issued", script.issuedDate?.longMedicationDate)
            detailRow("Expires", script.expiryDate?.longMedicationDate ?? "Not recorded")
            detailRow(
                "Repeats authorised",
                script.repeatsAuthorised.map(String.init)
            )
            detailRow("Repeats remaining", String(script.repeatsRemaining))
            detailRow("Last reviewed", script.lastReviewedAt?.longMedicationDate)
            detailRow("Notes", script.notes)
        }
        .medicationCard()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            FooterActionButton(
                title: "Record Refill",
                symbol: "arrow.down.circle",
                foreground: AppTheme.green,
                background: AppTheme.greenFill
            ) {
                pendingAction = .recordRefill
            }
            .disabled(script.repeatsRemaining <= 0)

            FooterActionButton(
                title: "Delete Script",
                symbol: "trash",
                foreground: AppTheme.red,
                background: AppTheme.redFill
            ) {
                pendingAction = .delete
            }
        }
    }

    private var statusSymbol: String {
        switch script.status {
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
        switch script.status {
        case .valid:
            AppTheme.green
        case .expired, .noRepeats:
            AppTheme.red
        case .reviewNeeded:
            AppTheme.blue
        }
    }

    private func recordRefill() {
        script.recordRefill()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveError = "The refill count was not changed. Please try again."
        }
    }

    private func deleteScript() {
        modelContext.delete(script)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "The refill script was not deleted. Please try again."
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(title)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text(value)
                    .foregroundStyle(AppTheme.title)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private enum ScriptAction: String, Identifiable {
    case recordRefill
    case delete

    var id: String { rawValue }
}
