import Foundation

class GeneralSettings: Model {
  enum BackupFrequency: Int {
    case manually = 0
    case hourly = 3600
    case daily = 86400
    case weekly = 604_800
    case custom = -1
  }

  @Published var launchAtLogin = false {
    didSet {
      guard !ignoringChanges else { return }

      AppEnvironment.shared.launchAtLogn = launchAtLogin
    }
  }

  @Published var backupFrequency = BackupFrequency.daily {
    didSet {
      guard !ignoringChanges else { return }
      guard backupFrequency != oldValue else { return }

      if backupFrequency != .custom {
        AppEnvironment.shared.backupFrequency = backupFrequency.rawValue
        ResticScheduler.shared.rescheduleStaleBackupCheck()
        ResticScheduler.shared.rescheduleBackup()
      }
    }
  }

  override init() {
    super.init()
    ignoringChanges {
      launchAtLogin = AppEnvironment.shared.launchAtLogn
      if let frequency = BackupFrequency(rawValue: AppEnvironment.shared.backupFrequency) {
        backupFrequency = frequency
      } else {
        backupFrequency = .custom
      }
    }
  }
}
