import SwiftData
import SwiftUI

@main
struct MedicationTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var router = AppRouter.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var appLock = AppLockService()

    private let modelContainer: ModelContainer
    private let storeError: String?

    init() {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains("--ui-testing")
        var launchError: String?
        let resolvedContainer: ModelContainer

        do {
            if isTesting {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
                resolvedContainer = try ModelContainer(
                    for: Medicine.self,
                    TreatmentPlan.self,
                    DoseEvent.self,
                    configurations: configuration
                )
            } else {
                resolvedContainer = try ModelContainer(
                    for: Medicine.self,
                    TreatmentPlan.self,
                    DoseEvent.self
                )
            }
        } catch {
            launchError = error.localizedDescription
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                resolvedContainer = try ModelContainer(
                    for: Medicine.self,
                    TreatmentPlan.self,
                    DoseEvent.self,
                    configurations: configuration
                )
            } catch {
                fatalError("Unable to create the medication store: \(error)")
            }
        }
        modelContainer = resolvedContainer
        storeError = launchError

        if UserDefaults.standard.object(forKey: SettingsKeys.snoozeMinutes) == nil {
            UserDefaults.standard.set(10, forKey: SettingsKeys.snoozeMinutes)
        }
        if storeError == nil {
            NotificationManager.shared.install(modelContainer: modelContainer)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if storeError == nil {
                    MainTabView()
                        .environment(router)
                        .environment(notificationManager)
                        .environment(appLock)
                } else {
                    DataStoreErrorView()
                }

                if storeError == nil && appLock.isEnabled && !appLock.isUnlocked {
                    LockScreenView()
                        .environment(appLock)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .preferredColorScheme(.light)
            .task {
                guard storeError == nil else { return }
                await notificationManager.refreshAuthorizationStatus()
                await notificationManager.rebuildAll(context: modelContainer.mainContext)
                if appLock.isEnabled && !appLock.isUnlocked {
                    await appLock.unlock()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    guard storeError == nil else { return }
                    Task {
                        await notificationManager.rebuildAll(context: modelContainer.mainContext)
                        if appLock.isEnabled && !appLock.isUnlocked {
                            await appLock.unlock()
                        }
                    }
                case .inactive, .background:
                    appLock.lock()
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(modelContainer)
    }
}

private struct DataStoreErrorView: View {
    var body: some View {
        VStack(spacing: 18) {
            CircularSymbol(
                name: "externaldrive.badge.exclamationmark",
                foreground: AppTheme.red,
                background: AppTheme.redFill,
                size: 72
            )
            Text("Medication data is unavailable")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.title)
                .multilineTextAlignment(.center)
            Text("The app could not safely open its local store. Your data has not been replaced. Close the app and try again.")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

private struct LockScreenView: View {
    @Environment(AppLockService.self) private var appLock

    var body: some View {
        VStack(spacing: 20) {
            CircularSymbol(name: "lock.shield", size: 72)
            Text("Medication Tracker is locked")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.title)
            Text("Use Face ID or your device passcode to continue.")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Unlock", systemImage: "faceid") {
                Task { await appLock.unlock() }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(minHeight: 48)
            .background(AppTheme.blue)
            .clipShape(.capsule)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .accessibilityAddTraits(.isModal)
    }
}
