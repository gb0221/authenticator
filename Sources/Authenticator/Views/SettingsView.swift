import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var settings = AppSettings.shared

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

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 140)
    }
}
