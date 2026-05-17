import Foundation
import Combine

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []

    private let metadataURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Authenticator", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.metadataURL = dir.appendingPathComponent("accounts.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        if let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: metadataURL, options: [.atomic])
    }

    func add(account: Account, secret: Data) throws {
        try Keychain.save(secret: secret, for: account.id)
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        persist()
    }

    struct ImportResult {
        var added: Int = 0
        var skippedDuplicates: Int = 0
        var failures: [(label: String, message: String)] = []
    }

    func addMany(_ items: [(Account, Data)]) -> ImportResult {
        var result = ImportResult()
        for (acc, secret) in items {
            if accounts.contains(where: {
                $0.issuer == acc.issuer && $0.name == acc.name
            }) {
                result.skippedDuplicates += 1
                continue
            }
            do {
                try add(account: acc, secret: secret)
                result.added += 1
            } catch {
                result.failures.append((label: acc.displayTitle, message: String(describing: error)))
            }
        }
        return result
    }

    func delete(_ account: Account) {
        try? Keychain.delete(id: account.id)
        accounts.removeAll { $0.id == account.id }
        persist()
    }

    func secret(for account: Account) -> Data? {
        try? Keychain.loadSecret(for: account.id)
    }

    func currentCode(for account: Account, at date: Date = Date()) -> String? {
        guard let secret = secret(for: account) else { return nil }
        return TOTP.code(secret: secret, account: account, at: date)
    }

    /// Increment the HOTP counter and persist. No-op for TOTP entries.
    /// Call after the user has consumed an HOTP code.
    func bumpCounter(for account: Account) {
        guard account.type == .hotp,
              let idx = accounts.firstIndex(where: { $0.id == account.id })
        else { return }
        accounts[idx].counter &+= 1
        persist()
    }
}
