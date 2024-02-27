import ResticSchedulerKit
import SettingsAccess
import SwiftUI

@main struct ResticSchedulerApp: App {
  @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @StateObject private var resticScheduler = ResticScheduler.shared

  private var destination: String {
    let resticRepository = AppEnvironment.shared.resticRepository
    var repositoryURL: URL?
    switch true {
    case resticRepository.hasPrefix(ResticSettings.RepositoryPrefix.sftp.rawValue + "//"):
      repositoryURL = URL(string: resticRepository)
    case resticRepository.hasPrefix(ResticSettings.RepositoryPrefix.sftp.rawValue):
      repositoryURL = URL(string: resticRepository.inserting(contentsOf: "//", at: ResticSettings.RepositoryPrefix.sftp.rawValue.endIndex))
    case resticRepository.hasPrefix(ResticSettings.RepositoryPrefix.rest.rawValue):
      let repository = resticRepository.droppingPrefix(ResticSettings.RepositoryPrefix.rest.rawValue)
      return URL(string: repository)!.host(percentEncoded: false)!
    default:
      return FileManager.default.displayName(atPath: resticRepository)
    }
    if let host = repositoryURL?.host(percentEncoded: false) {
      return host
    }

    return resticRepository
  }

  private var actionLabel: String {
    switch resticScheduler.status {
    case .stopping: "Stopping Backup…"
    case .idle: "Back Up Now"
    default: "Stop This Backup"
    }
  }

  private var lastSuccessfulBackup: String {
    let relativeDateFormatter = DateFormatter()
    relativeDateFormatter.timeStyle = .short
    relativeDateFormatter.dateStyle = .short
    relativeDateFormatter.doesRelativeDateFormatting = true
    return relativeDateFormatter.string(from: resticScheduler.lastSuccessfulBackup!)
  }

  var body: some Scene {
    MenuBarExtra("Restic Scheduler", systemImage: "umbrella.fill") {
      switch resticScheduler.status {
      case .preparation:
        Text("Preparing Backup…")
      case .backup:
        Text("\(resticScheduler.percentDone.formatted(.percent)) done – \(resticScheduler.bytesDone.formatted(.byteCount(style: .file))) copied")
      default:
        if resticScheduler.lastSuccessfulBackup != nil {
          Text("Latest Backup to “\(destination)”:")
          Text(lastSuccessfulBackup)
        } else {
          Text("Waiting to Complete First Backup")
        }
      }
      Divider()
      Button(actionLabel) {
        if resticScheduler.status == .idle {
          resticScheduler.backup()
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
    }
  }

  func showLogs() {
    guard let exists = try? AppEnvironment.shared.logURL.checkResourceIsReachable(), exists else {
      let alert = NSAlert()
      alert.messageText = "The log “\(AppEnvironment.shared.logURL.path(percentEncoded: false))” could not be opened. The file doesn’t exist."
      alert.alertStyle = .critical
      alert.addButton(withTitle: "OK")
      alert.runModal()
      return
    }

    NSWorkspace.shared.open(AppEnvironment.shared.logURL)
  }
}
