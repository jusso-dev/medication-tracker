import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AppLockService.self) private var appLock
    @Environment(NotificationManager.self) private var notificationManager

    @AppStorage(SettingsKeys.reminderLeadTime) private var reminderLeadTime = 0
    @AppStorage(SettingsKeys.snoozeMinutes) private var snoozeMinutes = 10

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
                privacySection
                aboutSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
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
}
