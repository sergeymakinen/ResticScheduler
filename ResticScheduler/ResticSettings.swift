import Combine

class ResticSettings: Model {
  enum RepositoryType {
    case local, sftp, rest, browse
  }

  enum RepositoryPrefix: String {
    case sftp = "sftp:"
    case rest = "rest:"
  }

  @Published var repositoryType = RepositoryType.local {
    willSet {
      if newValue == .browse {
        previousRepositoryType = repositoryType
      }
    }
    didSet {
      guard !ignoringChanges else { return }
      guard repositoryType != oldValue else { return }

      switch repositoryType {
      case .rest, .sftp:
        ignoringChanges {
          repository = ""
        }
      case .browse:
        browseRepository = true
        ignoringChanges {
          repositoryType = previousRepositoryType
        }
      default:
        break
      }
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var repository = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard repository != oldValue else { return }

      switch repositoryType {
      case .sftp:
        AppEnvironment.shared.resticRepository = RepositoryPrefix.sftp.rawValue + repository
      case .rest:
        AppEnvironment.shared.resticRepository = RepositoryPrefix.rest.rawValue + repository
      default:
        AppEnvironment.shared.resticRepository = repository
      }
      ResticScheduler.shared.lastSuccessfulBackup = nil
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var password = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard password != oldValue else { return }

      AppEnvironment.shared.resticPassword = password
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  var includes: [String] = [] {
    didSet {
      guard !ignoringChanges else { return }

      AppEnvironment.shared.resticIncludes = includes
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  var excludes: [String] = [] {
    didSet {
      guard !ignoringChanges else { return }

      AppEnvironment.shared.resticExcludes = excludes
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var browseRepository = false

  private var previousRepositoryType = RepositoryType.local

  override init() {
    super.init()
    ignoringChanges {
      let resticRepository = AppEnvironment.shared.resticRepository
      switch true {
      case resticRepository.hasPrefix(RepositoryPrefix.sftp.rawValue):
        repositoryType = .sftp
      case resticRepository.hasPrefix(RepositoryPrefix.rest.rawValue):
        repositoryType = .rest
      default:
        repositoryType = .local
      }
      switch repositoryType {
      case .sftp:
        repository = resticRepository.droppingPrefix(RepositoryPrefix.sftp.rawValue)
      case .rest:
        repository = resticRepository.droppingPrefix(RepositoryPrefix.rest.rawValue)
      default:
        repository = resticRepository
      }
      password = AppEnvironment.shared.resticPassword
      includes = AppEnvironment.shared.resticIncludes
      excludes = AppEnvironment.shared.resticExcludes
    }
  }
}
