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
    @State private var showingCareShare = false
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var backupDocument = MedicationBackupFile()
    @State private var backupStatus: String?
    @State private var backupError: String?

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
        .alert("Backup restored", isPresented: Binding(
            get: { backupStatus != nil },
            set: { if !$0 { backupStatus = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupStatus ?? "")
        }
        .alert("Backup failed", isPresented: Binding(
            get: { backupError != nil },
            set: { if !$0 { backupError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupError ?? "")
        }
        .sheet(isPresented: $showingCareShare) {
            CareShareView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: backupDocument,
            contentType: .medicationBackup,
            defaultFilename: "Medication-Tracker-Backup.medicationbackup"
        ) { result in
            if case .failure(let error) = result {
                backupError = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.medicationBackup, .data]
        ) { result in
            importBackup(result)
        }
        .onChange(of: appLock.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                showingCareShare = false
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

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Backup and restore")
            Label("Keep a copy of this log", systemImage: "externaldrive")
                .font(.headline)
                .foregroundStyle(AppTheme.title)
            Text("Export every medicine, plan, dose, refill script, and saved scan photo. Import merges by id. A file that cannot be read is left unused.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Button {
                exportBackup()
            } label: {
                Label("Export backup", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.blue)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backup.export")
            Button {
                showingBackupImporter = true
            } label: {
                Label("Import backup", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.blueFill)
                    .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backup.import")
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

    private func exportBackup() {
        do {
            backupDocument = MedicationBackupFile(
                data: try BackupRestoreService.exportArchive(context: modelContext)
            )
            showingBackupExporter = true
        } catch {
            backupError = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                try BackupRestoreService.importArchive(data, context: modelContext)
                Task {
                    await notificationManager.rebuildAll(context: modelContext)
                }
                backupStatus = "Medicines, plans, doses, scripts, and scan photos were merged by id."
            } catch {
                backupError = error.localizedDescription
            }
        case .failure(let error):
            backupError = error.localizedDescription
        }
    }
}
