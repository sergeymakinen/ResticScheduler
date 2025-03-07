import ResticSchedulerKit
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    private enum BackupFrequencyType: Int {
        case manually = 0
        case hourly = 3600
        case daily = 86400
        case weekly = 604_800
        case custom = -1
        case customize = -2
    }

    private typealias TypeLogger = ResticSchedulerKit.TypeLogger<GeneralSettingsView>

    @State private var customizeFrequency = false
    @EnvironmentObject private var resticScheduler: ResticScheduler
    @UserDefault(\.backupFrequency) private var backupFrequency

    var body: some View {
        VStack {
            Form {
                let launchAtLogin = Binding<Bool> {
                    SMAppService.mainApp.status == .enabled
                } set: { newValue in
                    do {
                        if newValue, SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        } else if !newValue, SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
                    }
                }

                Toggle("Launch at login", isOn: launchAtLogin)
                    .padding(.bottom, 10)

                let backupFrequencyType = Binding<BackupFrequencyType> {
                    if let backupFrequencyType = BackupFrequencyType(rawValue: backupFrequency) {
                        backupFrequencyType
                    } else {
                        .custom
                    }
                } set: { newValue in
                    switch newValue {
                    case .custom:
                        break
                    case .customize:
                        customizeFrequency = true
                    default:
                        backupFrequency = newValue.rawValue
                    }
                }

                Picker("Backup frequency:", selection: backupFrequencyType) {
                    if backupFrequencyType.wrappedValue == .custom {
                        Group {
                            let frequency = Frequency(seconds: backupFrequency)

                            Text("Automatically every \(frequency.amount) \(frequency.unit)")
                                .tag(BackupFrequencyType.custom)
                            Divider()
                        }
                    }
                    Text("Automatically every hour")
                        .tag(BackupFrequencyType.hourly)
                    Text("Automatically every day")
                        .tag(BackupFrequencyType.daily)
                    Text("Automatically every week")
                        .tag(BackupFrequencyType.weekly)
                    Text("Manually")
                        .tag(BackupFrequencyType.manually)
                    Divider()
                    Text("Custom…")
                        .tag(BackupFrequencyType.customize)
                }
                .sheet(isPresented: $customizeFrequency, onDismiss: { customizeFrequency = false }) {
                    FrequencySettingsView()
                }
            }
            .frame(width: 400, alignment: .center)
            .padding()
        }
        .onChange(of: backupFrequency) { _ in
            resticScheduler.rescheduleBackup()
            resticScheduler.rescheduleStaleBackupCheck()
        }
    }
}

#Preview {
    GeneralSettingsView()
}
