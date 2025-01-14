import Combine

class ResticSettings: Model {
  enum RepositoryType {
    case local, sftp, rest, s3, browse

    var hasAddress: Bool {
      switch self {
      case .local, .browse:
        false
      case .sftp, .rest, .s3:
        true
      }
    }
  }

  enum RepositoryPrefix: String {
    case sftp = "sftp:"
    case rest = "rest:"
    case s3 = "s3:"
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

      if repositoryType == .browse {
        browseRepository = true
        ignoringChanges {
          repositoryType = previousRepositoryType
        }
      } else {
        ignoringChanges {
          repository = ""
        }
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
      case .s3:
        AppEnvironment.shared.resticRepository = RepositoryPrefix.s3.rawValue + repository
      default:
        AppEnvironment.shared.resticRepository = repository
      }
      ResticScheduler.shared.lastSuccessfulBackup = nil
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var s3AccessKeyId = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard s3AccessKeyId != oldValue else { return }

      AppEnvironment.shared.s3AccessKeyId = s3AccessKeyId == "" ? nil : s3AccessKeyId
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var s3SecretAccessKey = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard s3SecretAccessKey != oldValue else { return }

      AppEnvironment.shared.s3SecretAccessKey = s3SecretAccessKey == "" ? nil : s3SecretAccessKey
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var restUsername = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard restUsername != oldValue else { return }

      AppEnvironment.shared.restUsername = restUsername == "" ? nil : restUsername
      ResticScheduler.shared.rescheduleStaleBackupCheck()
    }
  }

  @Published var restPassword = "" {
    didSet {
      guard !ignoringChanges else { return }
      guard restPassword != oldValue else { return }

      AppEnvironment.shared.restPassword = restPassword == "" ? nil : restPassword
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
      case resticRepository.hasPrefix(RepositoryPrefix.s3.rawValue):
        repositoryType = .s3
      default:
        repositoryType = .local
      }
      switch repositoryType {
      case .sftp:
        repository = resticRepository.droppingPrefix(RepositoryPrefix.sftp.rawValue)
      case .rest:
        repository = resticRepository.droppingPrefix(RepositoryPrefix.rest.rawValue)
      case .s3:
        repository = resticRepository.droppingPrefix(RepositoryPrefix.s3.rawValue)
      default:
        repository = resticRepository
      }
      s3AccessKeyId = AppEnvironment.shared.s3AccessKeyId ?? ""
      s3SecretAccessKey = AppEnvironment.shared.s3SecretAccessKey ?? ""
      restUsername = AppEnvironment.shared.restUsername ?? ""
      restPassword = AppEnvironment.shared.restPassword ?? ""
      password = AppEnvironment.shared.resticPassword
      includes = AppEnvironment.shared.resticIncludes
      excludes = AppEnvironment.shared.resticExcludes
    }
  }
}
