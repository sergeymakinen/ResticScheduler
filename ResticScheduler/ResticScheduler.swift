import Combine
import os
import ResticSchedulerKit
import UserNotifications

class ResticScheduler: Model, ResticSchedulerProtocol {
  enum Status {
    case idle, preparation, backup, stopping
  }

  private typealias TypeLogger = ResticSchedulerKit.TypeLogger<ResticScheduler>

  static let shared = ResticScheduler()

  private static let staleBackupCheckInterval = Duration.seconds(3600)

  @Published private(set) var percentDone: Float64 = 0
  @Published private(set) var bytesDone: UInt64 = 0
  @Published var status = Status.idle
  @Published var lastSuccessfulBackup: Date? {
    didSet {
      guard !ignoringChanges else { return }
      guard lastSuccessfulBackup != oldValue else { return }

      if let lastSuccessfulBackup {
        AppEnvironment.shared.lastSuccessfulBackupDate = lastSuccessfulBackup
      } else {
        AppEnvironment.shared.lastSuccessfulBackupDate = nil
      }
    }
  }

  var addNotificationHandler: ((UNNotificationContent) -> Void)?

  private let lock = OSAllocatedUnfairLock()
  private var backupScheduler: NSBackgroundActivityScheduler?
  private var staleBackupScheduler: NSBackgroundActivityScheduler?
  private var bag = Set<AnyCancellable>()

  private var isBackupStale: Bool {
    let interval = Duration.seconds(AppEnvironment.shared.backupFrequency)
    guard interval.components.seconds > 0 else { return false }

    return lastSuccessfulBackup == nil || lastSuccessfulBackup!.timeIntervalSinceNow >= TimeInterval(interval.components.seconds * 2)
  }

  override private init() {
    super.init()
    ignoringChanges {
      lastSuccessfulBackup = AppEnvironment.shared.lastSuccessfulBackupDate
    }
    rescheduleBackup()
    rescheduleStaleBackupCheck()
    NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &bag)
  }

  func progressDidUpdate(percentDone: Float64, bytesDone: UInt64) {
    lock.withLock {
      DispatchQueue.main.sync {
        if self.status == .preparation {
          self.status = .backup
        }
        self.percentDone = percentDone
        self.bytesDone = bytesDone
      }
    }
  }

  func backup(completion: @escaping (() -> Void) = {}) {
    lock.withLock {
      guard status == .idle else { return }

      status = .preparation
      ResticRunnerService.shared.backup(restic: Restic.environment()) { error in
        self.lock.withLock {
          DispatchQueue.main.sync {
            if error != nil {
              let content = UNMutableNotificationContent()
              content.title = "Backup Not Completed"
              content.body = "Restic Scheduler couldn’t complete the backup."
              content.userInfo[AppDelegate.NotificationUserInfoKey.localizedError.rawValue] = error!.localizedDescription
              content.categoryIdentifier = AppDelegate.NotificationCategoryIdentifier.backupFailure.rawValue
              self.addNotificationHandler?(content)
            } else {
              self.lastSuccessfulBackup = Date()
            }
            self.status = .idle
            completion()
          }
        }
      }
    }
  }

  func stop() {
    lock.withLock {
      guard status != .idle, status != .stopping else { return }

      ResticRunnerService.shared.stop { error in
        self.lock.withLock {
          DispatchQueue.main.sync {
            if error != nil {
              if self.status == .stopping {
                self.status = .idle
              }
              TypeLogger.function().error("\(error!.localizedDescription, privacy: .public)")
            } else {
              self.status = .idle
            }
          }
        }
      }
    }
  }

  func rescheduleBackup() {
    lock.withLock {
      backupScheduler?.invalidate()
      let interval = Duration.seconds(AppEnvironment.shared.backupFrequency)
      guard interval.components.seconds > 0 else { return }

      backupScheduler = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier!).backup")
      backupScheduler!.qualityOfService = .background
      backupScheduler!.interval = TimeInterval(interval.components.seconds)
      backupScheduler!.repeats = true
      backupScheduler!.schedule { [weak self] completion in
        guard let self, let scheduler = backupScheduler else {
          completion(.deferred)
          return
        }
        guard !scheduler.shouldDefer else {
          TypeLogger.function().info("Deferred backup as suggested")
          completion(.deferred)
          return
        }

        DispatchQueue.main.sync {
          self.backup {
            TypeLogger.function().info("Finished scheduled backup")
            completion(.finished)
          }
        }
      }
      TypeLogger.function().info("Rescheduled backups, interval: \(interval.formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .wide)), privacy: .public)")
    }
  }

  func rescheduleStaleBackupCheck() {
    lock.withLock {
      staleBackupScheduler?.invalidate()
      staleBackupScheduler = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier!).staleBackup")
      staleBackupScheduler!.qualityOfService = .background
      staleBackupScheduler!.interval = TimeInterval(Self.staleBackupCheckInterval.components.seconds)
      staleBackupScheduler!.schedule { [weak self] completion in
        guard let self, let scheduler = staleBackupScheduler else {
          completion(.deferred)
          return
        }
        guard !scheduler.shouldDefer else {
          TypeLogger.function().info("Deferred stale backup check as suggested")
          completion(.deferred)
          return
        }
        guard isBackupStale else {
          completion(.finished)
          return
        }

        DispatchQueue.main.sync {
          self.backup {
            TypeLogger.function().info("Finished scheduled stale backup")
            completion(.finished)
          }
        }
      }
      TypeLogger.function().info("Rescheduled stale backup check, interval: \(Self.staleBackupCheckInterval.formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .wide)), privacy: .public), stale: \(self.isBackupStale, privacy: .public)")
    }
  }
}
