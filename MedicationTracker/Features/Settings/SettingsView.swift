import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AppLockService.self) private var appLock
    @Environment(NotificationManager.self) private var notificationManager

    @AppStorage(SettingsKeys.reminderLeadTime) private var reminderLeadTime = 0
    @AppStorage(SettingsKeys.snoozeMinutes) private var snoozeMinutes = 10
    @AppStorage(SettingsKeys.lastBackupAt) private var lastBackupAt = 0.0
    @State private var showingCareShare = false
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var backupDocument: MedicationBackupDocument?
    @State private var backupIsBusy = false
    @State private var backupAlert: BackupAlert?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                notificationSection
                scheduleSection
                backupSection
                careShareSection
                privacySection
                aboutSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.visible)
        .background(AppTheme.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
        .onChange(of: reminderLeadTime) {
            Task {
                await notificationManager.rebuildAll(context: modelContext)
            }
        }
        .alert("App lock", isPresented: Binding(
            get: { appLock.errorMessage != nil },
            set: { if !$0 { appLock.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appLock.errorMessage ?? "")
        }
        .sheet(isPresented: $showingCareShare) {
            CareShareView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: appLock.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                showingCareShare = false
            }
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupDocument,
            contentType: .medicationBackup,
            defaultFilename: "Medication-Tracker-Backup.medbackup",
            onCompletion: backupExportDidComplete
        )
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.medicationBackup]
        ) { result in
            openBackup(result)
        }
        .alert(item: $backupAlert) { alert in
            if let backup = alert.backup {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .destructive(Text("Restore and replace")) {
                        restoreBackup(backup)
                    },
                    secondaryButton: .cancel()
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Notifications")

            HStack(spacing: 12) {
                CircularSymbol(name: notificationSymbol)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Medication reminders")
                        .font(.headline)
                        .foregroundStyle(AppTheme.title)
                    Text(notificationStatusText)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                notificationButton
            }
        }
        .medicationCard()
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Reminder timing")

            VStack(alignment: .leading, spacing: 10) {
                Text("Default reminder lead time")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
                Picker("Default reminder lead time", selection: $reminderLeadTime) {
                    Text("0 min").tag(0)
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.segmented)
            }

            LabeledContent("Snooze length", value: "\(snoozeMinutes) minutes")
            LabeledContent("Week starts", value: "Sunday")

            Text("Dose times stay at the same wall-clock time when your phone’s time zone changes.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Privacy")
            Toggle(isOn: appLockBinding) {
                Label("App lock", systemImage: "faceid")
                    .font(.headline)
                    .foregroundStyle(AppTheme.title)
            }
            .tint(AppTheme.blue)
            Text("Uses Face ID or the device passcode. Off by default.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Backup and restore")
            Label("Full local backup", systemImage: "externaldrive.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
            Text("Includes medications, scanned images, schedules, dose history, treatment plans, and refill scripts.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            LabeledContent("Last backup", value: lastBackupDescription)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)

            ViewThatFits {
                HStack(spacing: 10) {
                    backupButton
                    restoreButton
                }
                VStack(spacing: 10) {
                    backupButton
                    restoreButton
                }
            }

            Label(
                "Store backup files somewhere private. Anyone with the file can read its contents.",
                systemImage: "lock.open.trianglebadge.exclamationmark"
            )
            .font(.footnote)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    private var backupButton: some View {
        Button(action: prepareBackup) {
            Label(
                backupIsBusy ? "Preparing…" : "Create backup",
                systemImage: "square.and.arrow.up"
            )
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppTheme.blue)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(backupIsBusy)
        .accessibilityIdentifier("backup.create")
    }

    private var restoreButton: some View {
        Button {
            showingBackupImporter = true
        } label: {
            Label("Restore backup", systemImage: "square.and.arrow.down")
                .font(.headline)
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppTheme.blueFill)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(backupIsBusy)
        .accessibilityIdentifier("backup.restore")
    }

    private var careShareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Care sharing")
            Label("Share with a partner or loved one", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
            Text("Create a one-time snapshot and send it with the secure system AirDrop flow.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button {
                showingCareShare = true
            } label: {
                Label("Open Care Share", systemImage: "airdrop")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.blue)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("care-share.settings")
        }
        .medicationCard()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "About")
            Label("Medication Tracker", systemImage: "cross.case")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
            Text("Open source under the MIT Licence.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Divider()
            Label("Personal log only", systemImage: "exclamationmark.shield")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
            Text("Not medical advice and not a substitute for a pharmacist or a doctor.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .medicationCard()
    }

    @ViewBuilder
    private var notificationButton: some View {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            Button("Allow") {
                Task {
                    _ = await notificationManager.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
        case .denied:
            Button("Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .buttonStyle(.bordered)
        default:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.green)
                .accessibilityLabel("Notifications allowed")
        }
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { appLock.isEnabled },
            set: { enabled in
                Task {
                    _ = await appLock.setEnabled(enabled)
                }
            }
        )
    }

    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            "Not set"
        case .denied:
            "Off in iOS Settings"
        case .authorized:
            "Allowed"
        case .provisional:
            "Delivered quietly"
        case .ephemeral:
            "Temporarily allowed"
        @unknown default:
            "Unknown"
        }
    }

    private var notificationSymbol: String {
        notificationManager.authorizationStatus == .denied ? "bell.slash" : "bell"
    }

    private var lastBackupDescription: String {
        guard lastBackupAt > 0 else { return "Never" }
        return Date(timeIntervalSince1970: lastBackupAt).formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private func prepareBackup() {
        guard !backupIsBusy else { return }
        do {
            let backup = try MedicationBackupService.makeBackup(context: modelContext)
            backupIsBusy = true
            Task {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try MedicationBackupCodec.encode(backup)
                    }.value
                    backupDocument = MedicationBackupDocument(data: data)
                    showingBackupExporter = true
                } catch {
                    showBackupError(error)
                }
                backupIsBusy = false
            }
        } catch {
            showBackupError(error)
        }
    }

    private func backupExportDidComplete(_ result: Result<URL, Error>) {
        backupDocument = nil
        switch result {
        case .success:
            lastBackupAt = Date.now.timeIntervalSince1970
            backupAlert = BackupAlert(
                title: "Backup saved",
                message: "Your full Medication Tracker backup was exported.",
                backup: nil
            )
        case .failure(let error):
            let cocoaError = error as NSError
            guard cocoaError.domain != NSCocoaErrorDomain
                    || cocoaError.code != NSUserCancelledError else {
                return
            }
            showBackupError(error)
        }
    }

    private func openBackup(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result {
                showBackupError(error)
            }
            return
        }
        backupIsBusy = true
        Task {
            do {
                let backup = try await Task.detached(priority: .userInitiated) {
                    try MedicationBackupCodec.decode(contentsOf: url)
                }.value
                let eventCount = backup.medicines.flatMap(\.doseEvents).count
                backupAlert = BackupAlert(
                    title: "Restore this backup?",
                    message: "Created \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)). It contains \(backup.medicines.count) medications, \(backup.treatmentPlans.count) treatment plans, and \(eventCount) dose events. Restoring replaces all current app data.",
                    backup: backup
                )
            } catch {
                showBackupError(error)
            }
            backupIsBusy = false
        }
    }

    private func restoreBackup(_ backup: MedicationBackup) {
        guard !backupIsBusy else { return }
        backupIsBusy = true
        Task {
            do {
                try MedicationBackupService.restore(backup, context: modelContext)
                await notificationManager.rebuildAll(context: modelContext)
                backupAlert = BackupAlert(
                    title: "Backup restored",
                    message: "Your medications and history were restored successfully.",
                    backup: nil
                )
            } catch {
                showBackupError(error)
            }
            backupIsBusy = false
        }
    }

    private func showBackupError(_ error: Error) {
        backupAlert = BackupAlert(
            title: "Backup unavailable",
            message: (error as? LocalizedError)?.errorDescription
                ?? "The backup operation could not be completed.",
            backup: nil
        )
    }
}

private struct BackupAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let backup: MedicationBackup?
}
