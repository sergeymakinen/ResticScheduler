import Combine
import Foundation

class GeneralSettings: Model {
  enum BackupFrequency: Int {
    case manually = 0
    case hourly = 3600
    case daily = 86400
    case weekly = 604_800
    case custom = -1
    case customize = -2
  }

  @Published var launchAtLogin = false {
    didSet {
      guard !ignoringChanges else { return }

      AppEnvironment.shared.launchAtLogin = launchAtLogin
    }
  }

  @Published var backupFrequency = BackupFrequency.daily {
    willSet {
      if newValue == .customize {
        previousBackupFrequency = backupFrequency
      }
    }
    didSet {
      guard !ignoringChanges else { return }
      guard backupFrequency != oldValue else { return }

      switch backupFrequency {
      case .customize:
        customizeFrequency = true
        ignoringChanges {
          backupFrequency = previousBackupFrequency
        }
      case .custom:
        break
      default:
        AppEnvironment.shared.backupFrequency = backupFrequency.rawValue
        ResticScheduler.shared.rescheduleStaleBackupCheck()
        ResticScheduler.shared.rescheduleBackup()
      }
    }
  }

  @Published var customizeFrequency = false

  private var previousBackupFrequency = BackupFrequency.daily
  private var bag = Set<AnyCancellable>()

  override init() {
    super.init()
    ignoringChanges {
      launchAtLogin = AppEnvironment.shared.launchAtLogin
      if let frequency = BackupFrequency(rawValue: AppEnvironment.shared.backupFrequency) {
        backupFrequency = frequency
      } else {
        backupFrequency = .custom
      }
//      AppEnvironment.shared.$backupFrequency
//        .sink { [weak self] newValue in
//          self?.ignoringChanges {
//            if let frequency = BackupFrequency(rawValue: newValue) {
//              self?.backupFrequency = frequency
//            } else {
//              self?.backupFrequency = .custom
//            }
//          }
//          self?.objectWillChange.send()
//        }
//        .store(in: &bag)
    }
  }
}
