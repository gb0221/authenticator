import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var settings = AppSettings.shared
    @StateObject private var gate = BiometricGate.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Settings").font(.title3).fontWeight(.semibold)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            Toggle(isOn: Binding(
                get: { settings.openAtLogin },
                set: { settings.setOpenAtLogin($0) }
            )) {
                Text("Open at login")
            }

            Toggle(isOn: $settings.requireBiometrics) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Require Touch ID to reveal codes")
                    if !settings.biometricsAvailable {
                        Text("Biometrics not available on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!settings.biometricsAvailable)
            .onChange(of: settings.requireBiometrics) { _ in
                gate.relock()
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 200)
    }
}
