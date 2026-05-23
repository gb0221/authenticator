import Foundation
import ServiceManagement

/// User-facing settings, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published private(set) var openAtLogin: Bool

    private init() {
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
}
