import SwiftUI
import AppKit

struct AccountRow: View {
    @EnvironmentObject var store: AccountStore
    let account: Account
    let now: Date

    @State private var justCopied = false

    var body: some View {
        let code = store.currentCode(for: account, at: now) ?? "------"
        let remaining = TOTP.secondsRemaining(period: account.period, at: now)
        let progress = Double(remaining) / Double(max(1, account.period))

        Button {
            copy(code)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.issuer.isEmpty ? account.name : account.issuer)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if !account.issuer.isEmpty && !account.name.isEmpty {
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(formatCode(code))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                if account.type == .totp {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progressColor(remaining: remaining), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(remaining)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.secondary)
                        .help("HOTP — counter advances on copy")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(justCopied ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Code") { copy(code) }
            Divider()
            Button("Delete", role: .destructive) {
                store.delete(account)
            }
        }
    }

    private func formatCode(_ code: String) -> String {
        guard code.count == 6 || code.count == 8 else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return code[..<mid] + " " + code[mid...]
    }

    private func progressColor(remaining: Int) -> Color {
        if remaining <= 5 { return .red }
        if remaining <= 10 { return .orange }
        return .accentColor
    }

    private func copy(_ code: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
        justCopied = true
        if account.type == .hotp {
            store.bumpCounter(for: account)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            justCopied = false
        }
    }
}
