import SwiftData
import SwiftUI

struct CareShareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Medicine.name) private var medicines: [Medicine]
    @Query(sort: \TreatmentPlan.title) private var treatmentPlans: [TreatmentPlan]

    @State private var package: CareSharePackage?
    @State private var shareError: String?
    @State private var options = CareShareOptions()
    @State private var isPreparing = false
    @State private var preparationID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ProximityShareAnimation()

                    VStack(spacing: 7) {
                        Text("Share with someone you trust")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.title)
                            .multilineTextAlignment(.center)
                        Text("Create a one-time snapshot, then choose how to send it from the system share sheet.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    privacyOptions
                    snapshotSummary
                    sharingInstructions

                    if isPreparing {
                        ProgressView("Preparing snapshot…")
                            .frame(maxWidth: .infinity, minHeight: 54)
                    } else if let package, !package.medicines.isEmpty {
                        ShareLink(
                            item: CareShareDocument(package: package),
                            preview: SharePreview(
                                "Medication Care Snapshot",
                                image: Image(systemName: "heart.text.clipboard")
                            )
                        ) {
                            Label("Open Share Sheet", systemImage: "airdrop")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(AppTheme.blue)
                                .clipShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("care-share.open")
                    } else if let shareError {
                        Label(shareError, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.red)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.horizontal, 14)
                            .background(AppTheme.redFill)
                            .clipShape(.rect(cornerRadius: AppTheme.controlRadius))
                    } else {
                        Label("Add an active medicine before sharing", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.divider)
                            .clipShape(.capsule)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Care Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: prepareSnapshot)
        .onChange(of: options) {
            prepareSnapshot()
        }
    }

    private var privacyOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Choose optional details")
            Toggle("Notes and script notes", isOn: $options.includeNotes)
            Toggle(
                "Quantities and refill thresholds",
                isOn: $options.includeInventory
            )
            Toggle("Refill-script records", isOn: $options.includeRefillScripts)
            Toggle("Prescriber names", isOn: $options.includePrescriberNames)

            Text("Optional sensitive details are off until you choose them.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .tint(AppTheme.blue)
        .medicationCard()
    }

    private var snapshotSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "What will be shared")
            summaryRow(
                "Active medicines",
                value: package?.medicines.count ?? 0,
                symbol: "pill"
            )
            summaryRow(
                "Treatment plans",
                value: package?.treatmentPlans.count ?? 0,
                symbol: "heart.text.clipboard"
            )
            summaryRow(
                "Refill scripts",
                value: package?.medicines.flatMap(\.refillScripts).count ?? 0,
                symbol: "doc.text"
            )
            Divider()
            Text("Always included")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.title)
            Text("Medicine names and strengths, dose schedules, treatment dates, daily caps, package expiry dates, and treatment-plan titles.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Optional when enabled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.title)
            Text(optionalFieldsDescription)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Label("Dose history is not included", systemImage: "hand.raised")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Label("Imported reminders stay off until the recipient enables them", systemImage: "bell.slash")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    private var sharingInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Bring the iPhones together")
            Text("1. Tap Open Share Sheet and choose AirDrop.")
            Text("2. If both iPhones support proximity AirDrop, hold their top edges close together.")
            Text("3. The recipient accepts the file and reviews it in Medication Tracker before importing.")
            Text("AirDrop encrypts the transfer in transit. The snapshot file itself is readable by whoever receives it. Other share destinations use their own security.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.text)
        .medicationCard()
    }

    private var optionalFieldsDescription: String {
        var fields: [String] = []
        if options.includeNotes {
            fields.append("notes")
        }
        if options.includeInventory {
            fields.append("quantities and refill thresholds")
        }
        if options.includeRefillScripts {
            fields.append("script numbers, dates, repeats, and refill status")
        }
        if options.includePrescriberNames {
            fields.append("prescriber names")
        }
        return fields.isEmpty ? "None selected." : fields.joined(separator: ", ") + "."
    }

    private func summaryRow(
        _ title: String,
        value: Int,
        symbol: String
    ) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.text)
    }

    private func prepareSnapshot() {
        let candidate = CareShareService.makePackage(
            medicines: medicines,
            treatmentPlans: treatmentPlans,
            options: options
        )
        guard !candidate.medicines.isEmpty else {
            preparationID = nil
            isPreparing = false
            package = candidate
            shareError = nil
            return
        }
        let requestID = UUID()
        preparationID = requestID
        isPreparing = true
        package = nil
        shareError = nil
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try CareShareCodec.encode(candidate)
                }.value
                guard preparationID == requestID else { return }
                package = candidate
            } catch {
                guard preparationID == requestID else { return }
                shareError = (error as? LocalizedError)?.errorDescription
                    ?? "This care snapshot could not be prepared safely."
            }
            if preparationID == requestID {
                isPreparing = false
            }
        }
    }
}
