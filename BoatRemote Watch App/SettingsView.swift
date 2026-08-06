import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var service: AutopilotService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("t.ex. 192.168.1.50:3000", text: $service.serverHost)
                }
                Section("Token (valfritt)") {
                    TextField("JWT-token", text: $service.token)
                }
            }
            .navigationTitle("Inställningar")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(AutopilotService())
}
