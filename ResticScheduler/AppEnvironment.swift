import Foundation
import OSLog
import ServiceManagement

class AppEnvironment {
  static let shared = AppEnvironment()

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

  var launchAtLogin: Bool {
    get { SMAppService.mainApp.status == .enabled }
    set {
      do {
        if newValue, SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        } else if !newValue, SMAppService.mainApp.status == .enabled {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        logger.error("\(error.localizedDescription, privacy: .public)")
      }
    }
  }

  @UserDefault("BackupFrequency") var backupFrequency = 86400
  @UserDefault("ResticRepository") var resticRepository = FileManager.default.temporaryDirectory.path(percentEncoded: false)
  @UserDefault("ResticS3AccessKeyId") var s3AccessKeyId: String?
  @KeychainPassword("ResticS3SecretAccessKey") var s3SecretAccessKey: String?
  @KeychainPassword("ResticPassword") var resticPassword: String
  @UserDefault("ResticBinary") var resticBinary: String?
  @UserDefault("ResticHost") var resticHost: String?
  @UserDefault("ResticArguments") var resticArguments = ["--one-file-system", "--exclude-caches"]
  @UserDefault("ResticIncludes") var resticIncludes: [String] = []
  @UserDefault("ResticExcludes") var resticExcludes: [String] = []

  @UserDefault("LastSuccessfulBackupDate") var lastSuccessfulBackupDate: String?

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: AppEnvironment.self))

  private init() {}
}
