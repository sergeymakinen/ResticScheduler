import Combine
import Foundation
import os
import ResticSchedulerKit

class AdvancedSettings: Model {
  enum BinaryType {
    case manual, builtIn, browse
  }

  enum HostType {
    case custom, system
  }

  class BinaryVersion: ObservableObject {
    var value: String {
      refresh()
      return _value
    }

    var isError: Bool {
      refresh()
      return _error
    }

    private var needRefresh = true
    private var lock = OSAllocatedUnfairLock()
    private var _value = ""
    private var _error = false

    func invalidate() {
      lock.withLock {
        _value = ""
        _error = false
        needRefresh = true
      }
    }

    private func refresh() {
      lock.withLock {
        guard needRefresh else { return }

        ResticRunnerService.shared.version(restic: Restic.environment()) { [weak self] version, error in
          DispatchQueue.main.async { [weak self] in
            self?.lock.withLock { [weak self] in
              if error != nil {
                self?._value = error!.localizedDescription
                self?._error = true
              } else {
                self?._value = version!
              }
              self?.objectWillChange.send()
            }
          }
        }
        needRefresh = false
      }
    }
  }

  @Published var binaryType = BinaryType.manual {
    willSet {
      if newValue == .browse {
        previousBinaryType = binaryType
      }
    }
    didSet {
      guard !ignoringChanges else { return }
      guard binaryType != oldValue else { return }

      switch binaryType {
      case .builtIn:
        binary = nil
      case .browse:
        browseBinary = true
        ignoringChanges {
          binaryType = previousBinaryType
        }
      default:
        break
      }
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var binary: String? {
    didSet {
      guard !ignoringChanges else { return }
      guard binary != oldValue else { return }

      AppEnvironment.shared.resticBinary = binary
      binaryVersion.invalidate()
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var hostType = HostType.system {
    didSet {
      guard !ignoringChanges else { return }
      guard hostType != oldValue else { return }

      host = Host.current().localizedName!
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var host = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard host != oldValue else { return }

      switch hostType {
      case .system:
        AppEnvironment.shared.resticHost = nil
      case .custom:
        AppEnvironment.shared.resticHost = host
      }
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  var arguments: [String] = [] {
    didSet {
      guard !ignoringChanges else { return }
      guard arguments != oldValue else { return }

      AppEnvironment.shared.resticArguments = arguments
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var browseBinary = false
  @Published var binaryVersion = BinaryVersion()

  private var previousBinaryType = BinaryType.manual
  private var binaryVersionSubscriber: AnyCancellable?

  override init() {
    super.init()
    ignoringChanges {
      binaryType = AppEnvironment.shared.resticBinary == nil ? .builtIn : .manual
      binary = AppEnvironment.shared.resticBinary
      hostType = AppEnvironment.shared.resticHost == nil ? .system : .custom
      host = AppEnvironment.shared.resticHost ?? Host.current().localizedName!
      arguments = AppEnvironment.shared.resticArguments
    }
    binaryVersionSubscriber = binaryVersion.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
  }
}
