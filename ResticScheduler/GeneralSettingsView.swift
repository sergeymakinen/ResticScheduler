import SwiftUI

struct GeneralSettingsView: View {
  @StateObject private var generalSettings = GeneralSettings()

  var body: some View {
    VStack {
      Form {
        Toggle("Launch at login", isOn: $generalSettings.launchAtLogin)
          .padding(.bottom, 10)
        Picker("Backup frequency:", selection: $generalSettings.backupFrequency) {
          if generalSettings.backupFrequency == .custom {
            Group {
              let frequencySettings = FrequencySettings().current()
              Text("Automatically every \(frequencySettings.amount) \(frequencySettings.unit)")
                .tag(GeneralSettings.BackupFrequency.custom)
              Divider()
            }
          }
          Text("Automatically every hour")
            .tag(GeneralSettings.BackupFrequency.hourly)
          Text("Automatically every day")
            .tag(GeneralSettings.BackupFrequency.daily)
          Text("Automatically every week")
            .tag(GeneralSettings.BackupFrequency.weekly)
          Text("Manually")
            .tag(GeneralSettings.BackupFrequency.manually)
          Divider()
          Text("Custom…")
            .tag(GeneralSettings.BackupFrequency.customize)
        }
        .sheet(isPresented: $generalSettings.customizeFrequency, onDismiss: { generalSettings.customizeFrequency = false }) {
          FrequencySettingsView()
        }
      }
      .frame(width: 400, alignment: .center)
      .padding()
    }
  }
}

struct GeneralSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    GeneralSettingsView()
  }
}
