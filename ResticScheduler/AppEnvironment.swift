import Foundation
import OSLog
import ServiceManagement

@available(*, deprecated, message: "Use property wrappers directly in views")
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

    @UserDefault(\.backupFrequency) var backupFrequency
    @UserDefault(\.repository) var resticRepository
    @UserDefault(\.s3AccessKeyId) var s3AccessKeyId
    @KeychainPassword(\.s3SecretAccessKey) var s3SecretAccessKey
    @UserDefault(\.restUsername) var restUsername
    @KeychainPassword(\.restPassword) var restPassword
    @KeychainPassword(\.password) var resticPassword
    @UserDefault(\.binary) var resticBinary
    @UserDefault(\.host) var resticHost
    @UserDefault(\.arguments) var resticArguments
    @UserDefault(\.includes) var resticIncludes
    @UserDefault(\.excludes) var resticExcludes
    @UserDefault(\.lastSuccessfulBackupDate) var lastSuccessfulBackupDate

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: AppEnvironment.self))

    private init() {}
}
