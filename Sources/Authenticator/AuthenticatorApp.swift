import SwiftUI
import AppKit

@main
struct AuthenticatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Required by the App protocol; never shown.
        Settings { EmptyView() }
    }
}
