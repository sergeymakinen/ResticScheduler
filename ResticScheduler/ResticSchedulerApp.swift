import ResticSchedulerKit
import SettingsAccess
import SwiftUI

@main struct ResticSchedulerApp: App {
    private typealias TypeLogger = ResticSchedulerKit.TypeLogger<ResticSchedulerApp>

    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var resticScheduler = ResticScheduler()
    @UserDefault(\.repository) private var repository
    @UserDefault(\.lastSuccessfulBackupDate) private var lastSuccessfulBackupDate
    @UserDefault(\.localizedError) private var localizedError

    private var actionLabel: String {
        switch resticScheduler.status {
        case .stopping: lastSuccessfulBackupDate == nil ? "Stopping…" : "Skipping…"
        case .idle: "Back Up Now"
        default: lastSuccessfulBackupDate == nil ? "Stop This Backup" : "Skip This Backup"
        }
    }

    private var lastSuccessfulBackup: String {
        let relativeDateFormatter = DateFormatter()
        relativeDateFormatter.timeStyle = .short
        relativeDateFormatter.dateStyle = .short
        relativeDateFormatter.doesRelativeDateFormatting = true
        return relativeDateFormatter.string(from: lastSuccessfulBackupDate!)
    }

    var body: some Scene {
        MenuBarExtra("Restic Scheduler", image: resticScheduler.status == .idle ? "custom.umbrella.fill" : "custom.umbrella.fill.badge.clock") {
            switch resticScheduler.status {
            case .preparation:
                Text("Preparing to back up…")
            case .backup:
                Text("\(resticScheduler.percentDone.formatted(.percent)) done – \(resticScheduler.bytesDone.formatted(.byteCount(style: .file))) copied")
            default:
                if lastSuccessfulBackupDate != nil {
                    Text("Latest Backup to “\(formatRepository(repository))”")
                    Text(lastSuccessfulBackup)
                    if localizedError != nil {
                        Button("Backup Failed…", action: showError)
                    }
                } else {
                    Text("Waiting to Complete First Backup")
                }
            }
            Divider()
            Button(actionLabel) {
                if resticScheduler.status == .idle {
                    resticScheduler.backup { error in
                        if let error {
                            TypeLogger.function().error("Failed to run manual backup: \(error.localizedDescription, privacy: .public)")
                        } else {
                            TypeLogger.function().info("Finished manual backup")
                        }
                    }
                } else {
                    resticScheduler.stop()
                }
            }
            .disabled(resticScheduler.status == .stopping)
            Button("View Restic Logs…", action: showLogs)
            Divider()
            SettingsLink {
                Text("Settings…")
            } preAction: {} postAction: {
                for window in NSApp.windows {
                    if let windowId = window.identifier?.rawValue {
                        if windowId.contains("Settings") {
                            window.level = .floating
                            break
                        }
                    }
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("About Restic Scheduler") {
                NSApp.orderFrontStandardAboutPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit Restic Scheduler") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            SettingsView()
                .environmentObject(resticScheduler)
        }
    }

    func showLogs() {
        guard let exists = try? resticScheduler.logURL.checkResourceIsReachable(), exists else {
            NSAlert.showError(.logNotFound(logURL: resticScheduler.logURL))
            return
        }

        NSWorkspace.shared.open(resticScheduler.logURL)
    }

    func showError() {
        guard let localizedError else {
            return
        }

        NSAlert.showError(.backupFailure(repository: repository), informativeText: localizedError)
    }
}

func formatRepository(_ repository: String) -> String {
    var repositoryURL: URL?
    switch true {
    case repository.hasPrefix(RepositoryType.sftp.rawValue + "//"):
        repositoryURL = URL(string: repository)
    case repository.hasPrefix(RepositoryType.sftp.rawValue):
        repositoryURL = URL(string: repository.inserting(contentsOf: "//", at: RepositoryType.sftp.rawValue.endIndex))
    case repository.hasPrefix(RepositoryType.rest.rawValue):
        repositoryURL = URL(string: repository.droppingPrefix(RepositoryType.rest.rawValue))
    default:
        return FileManager.default.displayName(atPath: repository)
    }
    if let host = repositoryURL?.host(percentEncoded: false) {
        return host
    }

    return repository
}
