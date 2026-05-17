import SwiftUI
import AppKit

struct ExportView: View {
    @EnvironmentObject var store: AccountStore
    @State private var selected: Set<UUID> = []
    @State private var uris: [String] = []
    @State private var copyFeedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Export accounts")
                .font(.title2).fontWeight(.semibold)

            Text("Produces `otpauth-migration://` URIs in the same format as Google Authenticator's export. You can paste these into another compatible authenticator (or render them as QR codes) to transfer your vault.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            accountList

            HStack {
                Button("Select all") { selected = Set(store.accounts.map(\.id)) }
                Button("None") { selected.removeAll() }
                Spacer()
                Button("Generate") { generate() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }

            if !uris.isEmpty {
                Divider()
                output
            }

            HStack {
                Spacer()
                Button("Close") { AppDelegate.shared.closeExportWindow() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .onAppear { selected = Set(store.accounts.map(\.id)) }
    }

    private var accountList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.accounts) { account in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { selected.contains(account.id) },
                            set: { isOn in
                                if isOn { selected.insert(account.id) }
                                else    { selected.remove(account.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(account.issuer.isEmpty ? account.name : account.issuer)
                                    .font(.subheadline)
                                if !account.issuer.isEmpty && !account.name.isEmpty {
                                    Text(account.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 200)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3))
        )
    }

    @ViewBuilder
    private var output: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(uris.count) URI\(uris.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                if let feedback = copyFeedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Button("Copy all") { copyAll() }
            }
            ScrollView {
                Text(uris.joined(separator: "\n\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3))
            )
        }
    }

    private func generate() {
        let pairs: [(Account, Data)] = store.accounts.compactMap { acc in
            guard selected.contains(acc.id),
                  let secret = store.secret(for: acc)
            else { return nil }
            return (acc, secret)
        }
        uris = MigrationURI.encode(accounts: pairs)
    }

    private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(uris.joined(separator: "\n"), forType: .string)
        copyFeedback = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copyFeedback = nil
        }
    }
}
