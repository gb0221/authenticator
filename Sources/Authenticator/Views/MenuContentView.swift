import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var store: AccountStore
    @StateObject private var gate = BiometricGate.shared
    @State private var now = Date()
    @State private var query: String = ""
    @State private var settingsOpen: Bool = false
    @FocusState private var searchFocused: Bool

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var filtered: [Account] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.accounts }
        return store.accounts.filter {
            $0.issuer.lowercased().contains(q) ||
            $0.name.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !store.accounts.isEmpty && !isLocked {
                searchField
            }

            Divider()

            if isLocked {
                lockedState
            } else if store.accounts.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                noResults
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { account in
                            AccountRow(account: account, now: now)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 380)
            }

            Divider()
            footer
        }
        .background(escapeHandler)
        .onReceive(ticker) { now = $0 }
        .onAppear {
            // Auto-prompt for biometrics if required.
            if gate.isRequired && !gate.isUnlocked {
                gate.unlock()
            }
        }
        .sheet(isPresented: $settingsOpen) {
            SettingsView(isPresented: $settingsOpen)
                .environmentObject(store)
        }
    }

    /// Hidden Button whose .cancelAction shortcut fires on Escape, even when
    /// the search TextField has keyboard focus. Clears the filter first; if
    /// the filter is empty, closes the popover.
    private var escapeHandler: some View {
        Button("") {
            if !query.isEmpty {
                query = ""
                searchFocused = false
            } else {
                AppDelegate.shared.closePopover()
            }
        }
        .keyboardShortcut(.cancelAction)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var isLocked: Bool {
        gate.isRequired && !gate.isUnlocked
    }

    private var lockedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Locked")
                .font(.headline)
            if let err = gate.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            } else {
                Text("Authenticate to reveal codes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                gate.unlock()
            } label: {
                Label("Unlock", systemImage: "touchid")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var header: some View {
        HStack {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.tint)
            Text("Authenticator")
                .font(.headline)
            Spacer()
            Button {
                AppDelegate.shared.closePopover()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No accounts yet")
                .font(.headline)
            Text("Import from Google Authenticator using the export QR.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var noResults: some View {
        Text("No matches.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                AppDelegate.shared.showImportWindow()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.plain)

            Button {
                AppDelegate.shared.showExportWindow()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(store.accounts.isEmpty)

            Spacer()

            Button {
                settingsOpen = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
