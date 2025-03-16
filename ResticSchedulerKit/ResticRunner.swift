import Foundation

@objc public class BackupOptions: NSObject, NSSecureCoding {
    public enum CodingKeys: String, CodingKey {
        case logURL
        case summaryURL
        case arguments
        case includes
        case excludes
        case environment
        case beforeBackup
        case onSuccess
        case onFailure
    }

    public let logURL: URL
    public let summaryURL: URL
    public let arguments: [String]
    public let includes: [String]
    public let excludes: [String]
    public let environment: [String: String]
    public let beforeBackup: String?
    public let onSuccess: String?
    public let onFailure: String?

    public init(logURL: URL, summaryURL: URL, arguments: [String], includes: [String], excludes: [String], environment: [String: String], beforeBackup: String?, onSuccess: String?, onFailure: String?) {
        self.logURL = logURL
        self.summaryURL = summaryURL
        self.arguments = arguments
        self.includes = includes
        self.excludes = excludes
        self.environment = environment
        self.beforeBackup = beforeBackup
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    public static var supportsSecureCoding: Bool { true }

    public func encode(with coder: NSCoder) {
        coder.encode(logURL, forKey: CodingKeys.logURL.rawValue)
        coder.encode(summaryURL, forKey: CodingKeys.summaryURL.rawValue)
        coder.encode(arguments, forKey: CodingKeys.arguments.rawValue)
        coder.encode(includes, forKey: CodingKeys.includes.rawValue)
        coder.encode(excludes, forKey: CodingKeys.excludes.rawValue)
        coder.encode(environment, forKey: CodingKeys.environment.rawValue)
        coder.encode(beforeBackup, forKey: CodingKeys.beforeBackup.rawValue)
        coder.encode(onSuccess, forKey: CodingKeys.onSuccess.rawValue)
        coder.encode(onFailure, forKey: CodingKeys.onFailure.rawValue)
    }

    public required init?(coder: NSCoder) {
        logURL = coder.decodeObject(of: NSURL.self, forKey: CodingKeys.logURL.rawValue)! as URL
        summaryURL = coder.decodeObject(of: NSURL.self, forKey: CodingKeys.summaryURL.rawValue)! as URL
        arguments = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: CodingKeys.arguments.rawValue)! as [String]
        includes = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: CodingKeys.includes.rawValue)! as [String]
        excludes = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: CodingKeys.excludes.rawValue)! as [String]
        environment = coder.decodeDictionary(withKeyClass: NSString.self, objectClass: NSString.self, forKey: CodingKeys.environment.rawValue)! as [String: String]
        beforeBackup = coder.decodeObject(of: NSString.self, forKey: CodingKeys.beforeBackup.rawValue) as? String
        onSuccess = coder.decodeObject(of: NSString.self, forKey: CodingKeys.onSuccess.rawValue) as? String
        onFailure = coder.decodeObject(of: NSString.self, forKey: CodingKeys.onFailure.rawValue) as? String
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
        guard error.domain == Self.errorDomain else {
            return nil
        }

        switch error.code {
        case Code.abnormalTermination.rawValue:
            self = .abnormalTermination(
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
        guard error.domain == Self.errorDomain else {
            return nil
        }

        switch error.code {
        case Code.preparationInProcess.rawValue:
            self = .preparationInProcess
        case Code.backupInProcess.rawValue:
            self = .backupInProcess
        case Code.backupNotRunning.rawValue:
            self = .backupNotRunning
        default:
            return nil
        }
    }
}

@objc public protocol ResticRunnerProtocol {
    func version(binary: String?, reply: @escaping (String?, Error?) -> Void)
    func backup(binary: String?, options: BackupOptions, reply: @escaping (Error?) -> Void)
    func stop(reply: @escaping (Error?) -> Void)
}
