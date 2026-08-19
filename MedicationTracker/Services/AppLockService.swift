import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockService {
    var isUnlocked: Bool
    var isEnabled: Bool
    var errorMessage: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKeys.appLockEnabled)
        isEnabled = enabled
        isUnlocked = !enabled
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            guard await authenticate(reason: "Turn on app lock for your medication log") else {
                return false
            }
            UserDefaults.standard.set(true, forKey: SettingsKeys.appLockEnabled)
            isEnabled = true
            isUnlocked = true
        } else {
            UserDefaults.standard.set(false, forKey: SettingsKeys.appLockEnabled)
            isEnabled = false
            isUnlocked = true
            errorMessage = nil
        }
        return true
    }

    func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }

    func unlock() async {
        guard isEnabled else {
            isUnlocked = true
            return
        }
        isUnlocked = await authenticate(reason: "Unlock your medication log")
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = "Set up a device passcode before turning on app lock."
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            errorMessage = success ? nil : "Authentication was not completed."
            return success
        } catch {
            errorMessage = "Authentication was not completed."
            return false
        }
    }
}
