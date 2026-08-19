import SwiftData
import SwiftUI

struct CareShareImportView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(CareShareImportRouter.self) private var importRouter

    let package: CareSharePackage
    let modelContainer: ModelContainer

    @State private var successTrigger = 0
    @AccessibilityFocusState private var successHeadingIsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let summary = importRouter.importSummary {
                        successView(summary)
                    } else {
                        reviewView
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Review Care Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        importRouter.importSummary == nil ? "Cancel" : "Done"
                    ) {
                        dismiss()
                    }
                    .disabled(importRouter.isImporting)
                    .accessibilityIdentifier("care-share.import.close")
                }
            }
        }
        .interactiveDismissDisabled(importRouter.isImporting)
        .alert("Couldn’t import care snapshot", isPresented: Binding(
            get: { importRouter.importErrorMessage != nil },
            set: { if !$0 { importRouter.importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importRouter.importErrorMessage ?? "")
        }
        .onChange(of: importRouter.importSummary?.addedMedicines) { _, value in
            guard value != nil else { return }
            if !reduceMotion {
                successTrigger += 1
            }
            Task { @MainActor in
                await Task.yield()
                successHeadingIsFocused = true
            }
        }
        .onAppear {
            guard importRouter.importSummary != nil else { return }
            Task { @MainActor in
                await Task.yield()
                successHeadingIsFocused = true
            }
        }
    }

    private var reviewView: some View {
        VStack(spacing: 18) {
            CircularSymbol(
                name: "person.2.badge.gearshape",
                size: 72
            )

            VStack(spacing: 6) {
                Text("Medication care snapshot")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.title)
                Text("Shared \(package.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Review before importing")
                ForEach(package.medicines) { medicine in
                    DisclosureGroup {
                        VStack(spacing: 9) {
                            detailRow("Schedule", scheduleSummary(medicine))
                            detailRow(
                                "Treatment",
                                "\(medicine.startDate.displayText) – "
                                    + (medicine.endDate?.displayText ?? "Ongoing")
                            )
                            detailRow("Treatment plan", planTitle(for: medicine.planID))
                            detailRow(
                                "Plan prescriber",
                                planPrescriber(for: medicine.planID)
                            )
                            detailRow("Package expiry", medicine.packageExpiryDate?.displayText)
                            detailRow(
                                "Daily cap",
                                medicine.dailyCap.map { "\($0) doses" }
                            )
                            detailRow(
                                "Quantity remaining",
                                medicine.quantityRemaining?.medicationFormatted
                            )
                            detailRow(
                                "Refill threshold",
                                medicine.refillAt?.medicationFormatted
                            )
                            detailRow("Notes", medicine.notes)

                            ForEach(medicine.refillScripts) { script in
                                Divider()
                                Text("Refill script")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                detailRow("Script number", script.scriptNumber)
                                detailRow("Issued", script.issuedDate?.displayText)
                                detailRow("Expires", script.expiryDate?.displayText)
                                detailRow(
                                    "Repeats",
                                    script.repeatsAuthorised.map {
                                        "\(script.repeatsRemaining) remaining of \($0)"
                                    } ?? "\(script.repeatsRemaining) remaining"
                                )
                                detailRow("Prescriber", script.prescriber)
                                detailRow(
                                    "Last reviewed",
                                    script.lastReviewedAt?.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    )
                                )
                                detailRow("Script notes", script.notes)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        HStack(spacing: 12) {
                            CircularSymbol(name: "pill")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(medicine.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.title)
                                Text(
                                    "\(medicine.amount.medicationFormatted) "
                                        + "\(MedicineUnit(rawValue: medicine.unitRawValue)?.displayName ?? medicine.unitRawValue)"
                                )
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                    if medicine.id != package.medicines.last?.id {
                        Divider()
                    }
                }
            }
            .medicationCard()

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "\(package.treatmentPlans.count) treatment plans",
                    systemImage: "heart.text.clipboard"
                )
                Label(
                    "\(package.medicines.flatMap(\.refillScripts).count) refill scripts",
                    systemImage: "doc.text"
                )
                Label("No dose history", systemImage: "hand.raised")
                Label("Reminders import switched off", systemImage: "bell.slash")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .medicationCard()

            Text("Import only files you expected from someone you trust. Existing records with the same secure identifier are skipped.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: importSnapshot) {
                Group {
                    if importRouter.isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Import Care Snapshot", systemImage: "square.and.arrow.down")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.blue)
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(importRouter.isImporting || package.medicines.isEmpty)
            .accessibilityIdentifier("care-share.import")
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
            .font(.footnote)
        }
    }

    private func scheduleSummary(_ medicine: SharedMedicine) -> String {
        if medicine.asNeeded {
            return "As needed"
        }
        let symbols = Calendar.current.weekdaySymbols
        let days = medicine.daysOfWeek.sorted().compactMap { day in
            symbols.indices.contains(day - 1) ? symbols[day - 1] : nil
        }.joined(separator: ", ")
        let times = medicine.times.sorted().map(\.medicationTime).joined(separator: ", ")
        return "Days \(days) at \(times)"
    }

    private func planTitle(for id: UUID?) -> String? {
        guard let id else { return nil }
        return package.treatmentPlans.first { $0.id == id }?.title
    }

    private func planPrescriber(for id: UUID?) -> String? {
        guard let id else { return nil }
        return package.treatmentPlans.first { $0.id == id }?.prescriber
    }

    private func successView(_ summary: CareShareImportSummary) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(AppTheme.green)
                .symbolEffect(.bounce, value: successTrigger)
                .accessibilityHidden(true)

            Text("Care snapshot imported")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.title)
                .accessibilityFocused($successHeadingIsFocused)

            VStack(spacing: 10) {
                LabeledContent("Medicines added", value: "\(summary.addedMedicines)")
                LabeledContent("Refill scripts added", value: "\(summary.addedRefillScripts)")
                if summary.skippedMedicines > 0 {
                    LabeledContent(
                        "Existing medicines skipped",
                        value: "\(summary.skippedMedicines)"
                    )
                }
            }
            .medicationCard()

            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppTheme.blue)
            .clipShape(.capsule)
            .accessibilityIdentifier("care-share.import.done")
        }
        .accessibilityElement(children: .contain)
    }

    private func importSnapshot() {
        importRouter.importPackage(
            package,
            modelContainer: modelContainer
        )
    }
}
