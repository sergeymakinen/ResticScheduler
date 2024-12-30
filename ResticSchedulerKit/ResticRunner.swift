import Foundation

@objc public class Restic: NSObject, NSSecureCoding {
  public let repository: String
  public let password: String
  public let binary: String?
  public let host: String?
  public let environment: [String: String]
  public let arguments: [String]
  public let includes: [String]
  public let excludes: [String]
  public let logURL: URL
  public let summaryURL: URL

  public init(repository: String, password: String, host: String?, binary: String?, environment: [String: String], arguments: [String], includes: [String], excludes: [String], logURL: URL, summaryURL: URL) {
    self.repository = repository
    self.password = password
    self.host = host
    self.binary = binary
    self.environment = environment
    self.arguments = arguments
    self.includes = includes
    self.excludes = excludes
    self.logURL = logURL
    self.summaryURL = summaryURL
  }

  public static var supportsSecureCoding: Bool { true }

  public func encode(with coder: NSCoder) {
    coder.encode(repository, forKey: "repository")
    coder.encode(password, forKey: "password")
    coder.encode(binary, forKey: "binary")
    coder.encode(host, forKey: "host")
    coder.encode(environment, forKey: "environment")
    coder.encode(arguments, forKey: "arguments")
    coder.encode(includes, forKey: "includes")
    coder.encode(excludes, forKey: "excludes")
    coder.encode(logURL, forKey: "logURL")
    coder.encode(summaryURL, forKey: "summaryURL")
  }

  public required init?(coder: NSCoder) {
    repository = coder.decodeObject(of: NSString.self, forKey: "repository")! as String
    password = coder.decodeObject(of: NSString.self, forKey: "password")! as String
    binary = coder.decodeObject(of: NSString.self, forKey: "binary") as String?
    host = coder.decodeObject(of: NSString.self, forKey: "host") as String?
    environment = coder.decodeDictionary(withKeyClass: NSString.self, objectClass: NSString.self, forKey: "environment")! as [String: String]
    arguments = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: "arguments")! as [String]
    includes = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: "includes")! as [String]
    excludes = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: "excludes")! as [String]
    logURL = coder.decodeObject(of: NSURL.self, forKey: "logURL")! as URL
    summaryURL = coder.decodeObject(of: NSURL.self, forKey: "summaryURL")! as URL
  }
}

public enum ProcessError: CustomNSError, LocalizedError, _ObjectiveCBridgeableError {
  public enum Code: Int {
    case abnormalTermination = 1
  }

  public enum UserInfoKey: String {
    case terminationStatus = "TERMINATION_STATUS"
    case standardError = "STANDARD_ERROR"
  }

  case abnormalTermination(terminationStatus: Int32, standardError: String)

  public static let errorDomain = String(describing: Self.self)

  public var errorCode: Int {
    switch self {
    case .abnormalTermination: Code.abnormalTermination.rawValue
    }
  }

  public var errorUserInfo: [String: Any] {
    switch self {
    case let .abnormalTermination(terminationStatus, standardError):
      [
        NSLocalizedDescriptionKey: errorDescription!,
        UserInfoKey.terminationStatus.rawValue: terminationStatus,
        UserInfoKey.standardError.rawValue: standardError,
      ]
    }
  }

  public var errorDescription: String? {
    switch self {
    case let .abnormalTermination(terminationStatus, standardError): "Process exited with code \(terminationStatus): \(standardError != "" ? standardError : "<no output>")"
    }
  }

  public init?(_bridgedNSError error: NSError) {
    guard error.domain == Self.errorDomain else { return nil }

    switch error.code {
    case Code.abnormalTermination.rawValue:
      self = Self.abnormalTermination(
        terminationStatus: error.userInfo[UserInfoKey.terminationStatus.rawValue] as! Int32,
        standardError: error.userInfo[UserInfoKey.standardError.rawValue] as! String
      )
    default:
      return nil
    }
  }
}

public enum BackupError: CustomNSError, LocalizedError, _ObjectiveCBridgeableError {
  public enum Code: Int {
    case preparationInProcess = 1
    case backupInProcess = 2
    case backupNotRunning = 3
  }

  case preparationInProcess, backupInProcess, backupNotRunning

  public static let errorDomain = String(describing: Self.self)

  public var errorCode: Int {
    switch self {
    case .preparationInProcess: Code.preparationInProcess.rawValue
    case .backupInProcess: Code.backupInProcess.rawValue
    case .backupNotRunning: Code.backupNotRunning.rawValue
    }
  }

  public var errorDescription: String? {
    switch self {
    case .preparationInProcess: "Backup preparation in process"
    case .backupInProcess: "Backup in process"
    case .backupNotRunning: "Backup not running"
    }
  }

  public init?(_bridgedNSError error: NSError) {
    guard error.domain == Self.errorDomain else { return nil }

    switch error.code {
    case Code.preparationInProcess.rawValue:
      self = Self.preparationInProcess
    case Code.backupInProcess.rawValue:
      self = Self.backupInProcess
    case Code.backupNotRunning.rawValue:
      self = Self.backupNotRunning
    default:
      return nil
    }
  }
}

@objc public protocol ResticRunnerProtocol {
  func version(restic: Restic, reply: @escaping (String?, Error?) -> Void)
  func backup(restic: Restic, reply: @escaping (Error?) -> Void)
  func stop(reply: @escaping (Error?) -> Void)
}
