import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static private(set) var shared: AppDelegate!

    let store = AccountStore()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var importWindow: NSWindow?
    private var exportWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = otherRunningInstance() {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        configurePopover()
    }

    private func otherRunningInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let me = NSRunningApplication.current
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .first { $0 != me }
    }

    // MARK: - Status item

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        statusItem.behavior = []

        guard let button = statusItem.button else { return }

        if let image = NSImage(
            systemSymbolName: "lock.shield.fill",
            accessibilityDescription: "Authenticator"
        ) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "🔐"
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        let root = MenuContentView()
            .environmentObject(store)

        let host = NSHostingController(rootView: root)
        let pop = NSPopover()
        // .transient: dismisses when the user clicks outside or switches apps.
        // Codes are copied to the clipboard before any app switch, so we don't
        // need the popover to persist across focus changes — and persisting
        // made it too easy to get stuck inside the search field.
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 340, height: 480)
        pop.contentViewController = host
        self.popover = pop
    }

    func closePopover() {
        popover?.performClose(nil)
        BiometricGate.shared.relock()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            BiometricGate.shared.relock()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Don't auto-focus any text field; the user types into Filter only
            // after explicitly clicking it.
            popover.contentViewController?.view.window?.makeFirstResponder(nil)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Import window

    func showImportWindow() {
        popover.performClose(nil)

        if importWindow == nil {
            let root = ImportView().environmentObject(store)
            let host = NSHostingController(rootView: root)

            let win = NSWindow(contentViewController: host)
            win.title = "Add Accounts"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.setContentSize(NSSize(width: 520, height: 420))
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            importWindow = win
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        importWindow?.makeKeyAndOrderFront(nil)
    }

    func closeImportWindow() {
        importWindow?.close()
    }

    // MARK: - Export window

    func showExportWindow() {
        popover.performClose(nil)

        if exportWindow == nil {
            let root = ExportView().environmentObject(store)
            let host = NSHostingController(rootView: root)

            let win = NSWindow(contentViewController: host)
            win.title = "Export Accounts"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 560, height: 560))
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            exportWindow = win
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        exportWindow?.makeKeyAndOrderFront(nil)
    }

    func closeExportWindow() {
        exportWindow?.close()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let win = notification.object as? NSWindow else { return }
        if win === importWindow || win === exportWindow {
            // Return to menu-bar-only mode if no other tool windows remain.
            let anyOpen = [importWindow, exportWindow]
                .compactMap { $0 }
                .contains { $0 !== win && $0.isVisible }
            if !anyOpen {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
