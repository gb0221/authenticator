import Foundation
import ServiceManagement
import LocalAuthentication

/// User-facing settings, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let requireBiometrics = "requireBiometrics"
    }

    @Published var requireBiometrics: Bool {
        didSet { defaults.set(requireBiometrics, forKey: Key.requireBiometrics) }
    }

    @Published private(set) var openAtLogin: Bool

    private init() {
        self.requireBiometrics = defaults.bool(forKey: Key.requireBiometrics)
        self.openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: ignore failure (typically "requires user approval"
            // and the system prompts the user automatically).
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    var biometricsAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }
}
