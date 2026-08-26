import SwiftData
import SwiftUI

enum MedicationDataStore {
    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Medicine.self,
            TreatmentPlan.self,
            DoseEvent.self,
            RefillScript.self,
            configurations: configuration
        )
    }
}

@main
struct MedicationTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var router = AppRouter.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var appLock = AppLockService()
    @State private var careShareImportRouter = CareShareImportRouter.shared
    @AppStorage(SettingsKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false

    private let modelContainer: ModelContainer
    private let storeError: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || arguments.contains("--ui-testing")
        var launchError: String?
        let resolvedContainer: ModelContainer

        do {
            resolvedContainer = try MedicationDataStore.makeContainer(
                isStoredInMemoryOnly: isTesting
            )
        } catch {
            launchError = error.localizedDescription
            do {
                resolvedContainer = try MedicationDataStore.makeContainer(
                    isStoredInMemoryOnly: true
                )
            } catch {
                fatalError("Unable to create the medication store: \(error)")
            }
        }
        if launchError == nil {
            do {
                try CalendarDayMigration.migrateIfNeeded(
                    context: resolvedContainer.mainContext
                )
            } catch {
                launchError = error.localizedDescription
            }
        }
        modelContainer = resolvedContainer
        storeError = launchError

        if isTesting {
            UserDefaults.standard.set(
                !arguments.contains("--ui-testing-onboarding"),
                forKey: SettingsKeys.hasCompletedOnboarding
            )
        } else if launchError == nil,
                  UserDefaults.standard.object(
                    forKey: SettingsKeys.hasCompletedOnboarding
                  ) == nil {
            let hasExistingData = ((try? resolvedContainer.mainContext.fetchCount(
                FetchDescriptor<Medicine>()
            )) ?? 0) > 0 || ((try? resolvedContainer.mainContext.fetchCount(
                FetchDescriptor<TreatmentPlan>()
            )) ?? 0) > 0
            UserDefaults.standard.set(
                hasExistingData,
                forKey: SettingsKeys.hasCompletedOnboarding
            )
        }

        if isTesting && arguments.contains("--ui-testing-seed") {
            try? UITestSeeder.seed(context: modelContainer.mainContext)
        }
        if isTesting && ProcessInfo.processInfo.arguments.contains("--ui-testing-import") {
            CareShareImportRouter.shared.pendingPackage = UITestSeeder.importPackage()
        }

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
                    if hasCompletedOnboarding {
                        MainTabView()
                            .environment(router)
                            .environment(notificationManager)
                            .environment(appLock)
                    } else {
                        OnboardingView {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hasCompletedOnboarding = true
                            }
                        }
                    }
                } else {
                    DataStoreErrorView()
                }

                if storeError == nil
                    && hasCompletedOnboarding
                    && appLock.isEnabled
                    && !appLock.isUnlocked {
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
            .onOpenURL { url in
                careShareImportRouter.open(url)
            }
            .sheet(item: pendingCareShareImport) { package in
                CareShareImportView(
                    package: package,
                    modelContainer: modelContainer
                )
                    .environment(careShareImportRouter)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .alert("Could not open care snapshot", isPresented: Binding(
                get: { careShareImportRouter.errorMessage != nil },
                set: { if !$0 { careShareImportRouter.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(careShareImportRouter.errorMessage ?? "")
            }
        }
        .modelContainer(modelContainer)
    }

    private var pendingCareShareImport: Binding<CareSharePackage?> {
        Binding(
            get: {
                guard storeError == nil,
                      !appLock.isEnabled || appLock.isUnlocked else {
                    return nil
                }
                return careShareImportRouter.pendingPackage
            },
            set: { package in
                if let package {
                    careShareImportRouter.pendingPackage = package
                } else {
                    careShareImportRouter.clear()
                }
            }
        )
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
