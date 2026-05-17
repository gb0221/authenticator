import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var store: AccountStore
    @State private var pasted: String = ""
    @State private var status: ImportStatus = .idle
    @State private var isTargeted: Bool = false

    enum ImportStatus: Equatable {
        case idle
        case scanning
        case success(Int)
        case error(String)
        case skipped(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import accounts")
                .font(.title2).fontWeight(.semibold)

            Text("Paste an `otpauth-migration://` URI (Google Authenticator export) or a regular `otpauth://totp/...` URI. You can also drop a screenshot of the QR code below.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $pasted)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )

            dropZone

            statusView

            HStack {
                Button("Close") { closeWindow() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                Button("Import") { importPasted() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 24))
                Text("Drop a QR-code image here")
                    .font(.callout)
                Text("PNG, JPEG, or HEIC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .onDrop(
            of: [.fileURL, .image, .png, .jpeg, .tiff, .heic],
            isTargeted: $isTargeted
        ) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .scanning:
            Label("Scanning…", systemImage: "magnifyingglass")
                .foregroundStyle(.secondary)
        case .success(let n):
            Label("Imported \(n) account\(n == 1 ? "" : "s").", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped(let msg):
            Label(msg, systemImage: "info.circle.fill")
                .foregroundStyle(.orange)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else {
            status = .error("Nothing was dropped.")
            return
        }
        status = .scanning

        // Prefer file URL, fall back to any image data the provider exposes.
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                DispatchQueue.main.async {
                    if let url {
                        let strings = QRImageScanner.scan(url: url)
                        importStrings(strings, fromImage: true)
                    } else {
                        status = .error("Couldn't read dropped file: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }
            return
        }

        let imageTypes = [UTType.png, .jpeg, .tiff, .heic, .image]
        for type in imageTypes {
            guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                DispatchQueue.main.async {
                    guard
                        let data,
                        let nsImage = NSImage(data: data),
                        let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    else {
                        status = .error("Couldn't decode the dropped image: \(error?.localizedDescription ?? "unknown error")")
                        return
                    }
                    let strings = QRImageScanner.scan(cgImage: cg)
                    importStrings(strings, fromImage: true)
                }
            }
            return
        }

        status = .error("Drop didn't carry a file or image. Try saving the screenshot to disk and dragging from Finder.")
    }

    private func importPasted() {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        importStrings(lines, fromImage: false)
    }

    private func importStrings(_ strings: [String], fromImage: Bool) {
        guard !strings.isEmpty else {
            status = .error(fromImage
                ? "No QR code found in the dropped image."
                : "Nothing to import.")
            return
        }

        var items: [(Account, Data)] = []
        var bad = 0
        for s in strings {
            if let parsed = MigrationURI.parse(s) {
                items.append(contentsOf: parsed)
            } else if let single = OtpAuthURI.parse(s) {
                items.append(single)
            } else {
                bad += 1
            }
        }

        guard !items.isEmpty else {
            status = .error("Couldn't recognize an otpauth:// or otpauth-migration:// URI.")
            return
        }

        let result = store.addMany(items)

        if !result.failures.isEmpty {
            let names = result.failures.map(\.label).joined(separator: ", ")
            status = .error("Couldn't save \(result.failures.count) account\(result.failures.count == 1 ? "" : "s"): \(names). \(result.failures.first?.message ?? "")")
        } else if result.added == 0 {
            status = .skipped("All \(items.count) account\(items.count == 1 ? "" : "s") already exist.")
        } else if result.skippedDuplicates > 0 {
            status = .skipped("Imported \(result.added); \(result.skippedDuplicates) already existed.")
        } else {
            status = .success(result.added)
        }
        pasted = ""
    }

    private func closeWindow() {
        AppDelegate.shared.closeImportWindow()
    }

    private func pasteFromClipboard() {
        let pb = NSPasteboard.general

        // Try image first — Cmd-Shift-Ctrl-4 puts a PNG on the clipboard.
        let imageClasses: [AnyClass] = [NSImage.self]
        if let images = pb.readObjects(forClasses: imageClasses, options: nil) as? [NSImage],
           let img = images.first,
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            status = .scanning
            let strings = QRImageScanner.scan(cgImage: cg)
            importStrings(strings, fromImage: true)
            return
        }

        // Fall back to text — append to the paste field and run import on it.
        if let text = pb.string(forType: .string), !text.isEmpty {
            pasted = text
            importPasted()
            return
        }

        status = .error("Clipboard has no image or text.")
    }
}
