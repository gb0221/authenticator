import Foundation
import LocalAuthentication

/// Runtime gate that allows revealing codes only after the user has authenticated
/// with biometrics. The unlock persists for the lifetime of the popover; on next
/// open the user must authenticate again.
@MainActor
final class BiometricGate: ObservableObject {
    static let shared = BiometricGate()

    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var lastError: String?

    private init() {}

    var isRequired: Bool {
        AppSettings.shared.requireBiometrics && AppSettings.shared.biometricsAvailable
    }

    /// Resets the unlocked state so the next reveal requires a fresh authentication.
    func relock() {
        isUnlocked = false
        lastError = nil
    }

    func unlock() {
        guard isRequired else {
            isUnlocked = true
            return
        }
        let ctx = LAContext()
        ctx.localizedReason = "Unlock Authenticator codes"
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock Authenticator codes"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.isUnlocked = true
                    self.lastError = nil
                } else {
                    self.isUnlocked = false
                    self.lastError = error?.localizedDescription
                }
            }
        }
    }
}
