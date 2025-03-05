import Cocoa
import Combine
import os
import ResticSchedulerKit
import UserNotifications

class ResticScheduler: ObservableObject, ResticSchedulerProtocol {
    enum Status {
        case idle, preparation, backup, stopping
    }

    private typealias TypeLogger = ResticSchedulerKit.TypeLogger<ResticScheduler>

    private static let staleBackupCheckInterval = Duration.seconds(3600)

    var logURL: URL {
        try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Logs", directoryHint: .isDirectory)
            .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
            .appending(path: "restic.log", directoryHint: .notDirectory)
    }

    var summaryURL: URL {
        try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
            .appending(path: "summary.json", directoryHint: .notDirectory)
    }

    @Published private(set) var percentDone: Float64 = 0
    @Published private(set) var bytesDone: UInt64 = 0
    @Published var status = Status.idle

    @UserDefault(\.backupFrequency) private var backupFrequency
    @UserDefault(\.lastSuccessfulBackupDate) private var lastSuccessfulBackupDate
    @UserDefault(\.binary) private var binary

    private let runner = ResticRunner()
    private let lock = OSAllocatedUnfairLock()
    private var backupScheduler: NSBackgroundActivityScheduler?
    private var staleBackupScheduler: NSBackgroundActivityScheduler?
    private var bag = Set<AnyCancellable>()

    private var isBackupStale: Bool {
        let interval = Duration.seconds(backupFrequency)
        guard interval.components.seconds > 0 else {
            return false
        }

        return lastSuccessfulBackupDate == nil || lastSuccessfulBackupDate!.timeIntervalSinceNow >= TimeInterval(interval.components.seconds * 2)
    }

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    init() {
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
                if status == .preparation {
                    status = .backup
                }
                self.percentDone = percentDone
                self.bytesDone = bytesDone
            }
        }
    }

    func backup(completion _: @escaping (() -> Void) = {}) {
        lock.withLock {
            guard status == .idle else {
                return
            }

            status = .preparation
//            runner.backup(restic: Restic.environment()) { error in
//                lock.withLock {
//                    DispatchQueue.main.sync {
//                        if error != nil {
//                            let content = UNMutableNotificationContent()
//                            content.title = "Backup Not Completed"
//                            content.body = "Restic Scheduler couldn’t complete the backup."
//                            content.userInfo[AppDelegate.NotificationUserInfoKey.localizedError.rawValue] = error!.localizedDescription
//                            content.categoryIdentifier = AppDelegate.NotificationCategoryIdentifier.backupFailure.rawValue
//                            addNotificationHandler?(content)
//                        } else {
//                            lastSuccessfulBackupDate = Date()
//                        }
//                        status = .idle
//                        completion()
//                    }
//                }
//            }
        }
    }

    func stop() {
        lock.withLock {
            guard status != .idle, status != .stopping else {
                return
            }

            runner.stop { [weak self] error in
                guard let self else {
                    return
                }

                lock.withLock {
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

    func version(completion: @escaping (String?, Error?) -> Void) {
        runner.version(binary: binary, reply: completion)
    }

    func rescheduleBackup() {
        lock.withLock {
            backupScheduler?.invalidate()
            let interval = Duration.seconds(backupFrequency)
            guard interval.components.seconds > 0 else {
                return
            }

            backupScheduler = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier!).backup")
            backupScheduler!.qualityOfService = .background
            backupScheduler!.interval = TimeInterval(interval.components.seconds)
            backupScheduler!.repeats = true
            backupScheduler!.schedule { [weak self] completion in
                guard let self, let backupScheduler else {
                    completion(.deferred)
                    return
                }
                guard !backupScheduler.shouldDefer else {
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
            staleBackupScheduler = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier!).staleBackupCheck")
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
