import Foundation
import os
import ResticSchedulerKit

class ResticRunnerService: ResticRunnerProtocol {
    private typealias TypeLogger = ResticSchedulerKit.TypeLogger<ResticRunnerService>

    private enum Status {
        case preparation, backup, idle
    }

    private struct Message: Decodable {
        enum CodingKeys: String, CodingKey {
            case messageType = "message_type"
        }

        let messageType: String
    }

    private struct StatusMessage: Decodable {
        enum CodingKeys: String, CodingKey {
            case percentDone = "percent_done"
            case bytesDone = "bytes_done"
        }

        let percentDone: Float64
        let bytesDone: UInt64?
    }

    private enum HookType: String, CustomStringConvertible {
        case beforeBackup = "before_backup"
        case onSuccess = "on_success"
        case onFailure = "on_failure"

        var description: String {
            switch self {
            case .beforeBackup:
                "before backup"
            case .onSuccess:
                "on success"
            case .onFailure:
                "on failure"
            }
        }
    }

    private static let status = OSAllocatedUnfairLock(initialState: Status.idle)
    private static let process = OSAllocatedUnfairLock<Process?>(initialState: nil)
    private static let logPadding = String(repeating: " ", count: 16)

    private let connection: NSXPCConnection

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    func version(binary: String?, reply: @escaping (String?, Error?) -> Void) {
        let process = Process()
        process.qualityOfService = .userInitiated
        guard let executableURL = resticURL(forBinary: binary) else {
            reply(nil, ProcessError.missingRestic)
            return
        }

        process.executableURL = executableURL
        process.arguments = ["version"]
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                reply(String(contentsOfPipe: standardOutput), nil)
            } else {
                let error = ProcessError.abnormalTermination(terminationStatus: process.terminationStatus, standardError: String(contentsOfPipe: standardError))
                TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
                reply(nil, error)
            }
        } catch {
            TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
            reply(nil, error)
        }
    }

    func backup(binary: String?, options: BackupOptions, reply: @escaping (Error?) -> Void) {
        let idle = Self.status.withLock { value in
            if value != .idle {
                reply(value == .preparation ? BackupError.preparationInProcess : BackupError.backupInProcess)
                return false
            }

            value = .preparation
            return true
        }
        if !idle {
            return
        }

        defer { Self.status.withLock { value in value = .idle }}
        let resticScheduler = OSAllocatedUnfairLock<ResticSchedulerProtocol?>(initialState: nil)
        resticScheduler.withLock { value in
            value = connection.activateRemoteObjectProxyWithErrorHandler(protocol: ResticSchedulerProtocol.self) { error in
                TypeLogger.function().warning("Error in Restic Runner <-> Restic Scheduler XPC: \(error.localizedDescription, privacy: .public)")
                resticScheduler.withLock { value in value = nil }
            }
        }
        let process = Process()
        process.qualityOfService = .background
        guard let executableURL = resticURL(forBinary: binary) else {
            reply(ProcessError.missingRestic)
            return
        }

        process.executableURL = executableURL
        process.environment = ProcessInfo.processInfo.environment
            .merging(options.environment) { _, new in new }
            .merging(["RESTIC_PROGRESS_FPS": "0.2"]) { _, new in new }
        do {
            try FileManager.default.createDirectory(at: options.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "\(Date().formatted(.rfc3164)) Starting backup...\n".append(to: options.logURL, encoding: .utf8)
            if let beforeBackup = options.beforeBackup {
                runHook(beforeBackup, ofType: .beforeBackup, loggingTo: options.logURL)
            }
            let cacheURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
            let supportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            let includesURL = supportURL.appending(path: "includes", directoryHint: .notDirectory)
            let excludesURL = supportURL.appending(path: "excludes", directoryHint: .notDirectory)
            try options.includes.joined(separator: "\n").write(to: includesURL, atomically: true, encoding: .utf8)
            try options.excludes.joined(separator: "\n").write(to: excludesURL, atomically: true, encoding: .utf8)
            process.arguments = [
                "--json",
                "--cache-dir", cacheURL.path(percentEncoded: false), "--cleanup-cache",
                "backup",
            ] + options.arguments + [
                "--files-from", includesURL.path(percentEncoded: false),
                "--exclude-file", excludesURL.path(percentEncoded: false),
            ]
            let standardOutput = Pipe()
            let standardError = Pipe()
            var standardErrorOutput = ""
            process.standardOutput = standardOutput
            process.standardError = standardError
            var summary: String?
            let decoder = JSONDecoder()
            standardOutput.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }

                if let message = try? decoder.decode(Message.self, from: data) {
                    switch message.messageType {
                    case "status":
                        if let status = try? decoder.decode(StatusMessage.self, from: data) {
                            resticScheduler.withLock { value in value?.progressDidUpdate(percentDone: round(status.percentDone * 100) / 100.0, bytesDone: status.bytesDone ?? 0) }
                        } else {
                            let value = String(data: data, encoding: .utf8)
                            TypeLogger.function().warning("Invalid status message: \(value ?? "<no value>", privacy: .public)")
                        }
                    case "summary":
                        summary = String(data: data, encoding: .utf8)
                    default:
                        break
                    }
                } else {
                    let value = String(data: data, encoding: .utf8)
                    TypeLogger.function().warning("Unexpected message: \(value ?? "<no value>", privacy: .public)")
                }
            }
            standardError.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }

                let value = String(data: data, encoding: .utf8)
                if let value {
                    standardErrorOutput += value
                }
                do {
                    try value?
                        .prefixingLines(with: Self.logPadding)
                        .append(to: options.logURL, encoding: .utf8)
                } catch {
                    TypeLogger.function().warning("Couldn't write log: \(error.localizedDescription, privacy: .public)")
                }
            }
            try process.run()
            Self.process.withLock { value in value = process }
            process.waitUntilExit()
            if process.terminationStatus == 0 || process.terminationStatus == 3 {
                if summary != nil {
                    do {
                        try FileManager.default.createDirectory(at: options.summaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try summary!.write(to: options.summaryURL, atomically: true, encoding: .utf8)
                    } catch {
                        TypeLogger.function().warning("Couldn't write summary: \(error.localizedDescription, privacy: .public)")
                    }
                }
                if let onSuccess = options.onSuccess {
                    runHook(onSuccess, ofType: .onSuccess, loggingTo: options.logURL)
                }
                do {
                    try "\n".append(to: options.logURL, encoding: .utf8)
                } catch {
                    TypeLogger.function().warning("Couldn't write log: \(error.localizedDescription, privacy: .public)")
                }
                reply(nil)
            } else {
                let error = ProcessError.abnormalTermination(terminationStatus: process.terminationStatus, standardError: standardErrorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
                TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
                if let onFailure = options.onFailure {
                    runHook(onFailure, ofType: .onFailure, loggingTo: options.logURL)
                }
                do {
                    try "\n".append(to: options.logURL, encoding: .utf8)
                } catch {
                    TypeLogger.function().warning("Couldn't write log: \(error.localizedDescription, privacy: .public)")
                }
                reply(error)
            }
        } catch {
            TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
            reply(error)
        }
    }

    func stop(reply: @escaping (Error?) -> Void) {
        Self.process.withLock { value in
            guard value != nil else {
                let error = BackupError.backupNotRunning
                TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
                reply(error)
                return
            }

            value!.terminate()
            reply(nil)
        }
    }

    func includesBuiltIn(reply: @escaping (Bool) -> Void) {
        reply(resticURL(forBinary: nil) != nil)
    }

    private func runHook(_ hook: String, ofType type: HookType, loggingTo logURL: URL) {
        do {
            try "\(Self.logPadding)Invoking \(type) hook...\n".append(to: logURL, encoding: .utf8)
        } catch {
            TypeLogger.function().warning("Couldn't write log: \(error.localizedDescription, privacy: .public)")
        }
        let process = Process()
        process.qualityOfService = .background
        process.executableURL = URL(fileURLWithPath: hook)
        process.arguments = [type.rawValue]
        process.environment = ProcessInfo.processInfo.environment
        process.standardOutput = nil
        let standardError = Pipe()
        var standardErrorOutput = ""
        process.standardError = standardError
        do {
            standardError.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }

                let value = String(data: data, encoding: .utf8)
                if let value {
                    standardErrorOutput += value
                }
                do {
                    try value?
                        .prefixingLines(with: Self.logPadding)
                        .append(to: logURL, encoding: .utf8)
                } catch {
                    TypeLogger.function().warning("Couldn't write log: \(error.localizedDescription, privacy: .public)")
                }
            }
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let error = ProcessError.abnormalTermination(terminationStatus: process.terminationStatus, standardError: standardErrorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
                TypeLogger.function().error("Failed to run \(type) hook: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
        }
    }
}

func resticURL(forBinary binary: String?) -> URL? {
    guard let binary, !binary.isEmpty else {
        return Bundle.main.url(forResource: "restic", withExtension: "")
    }

    return URL(fileURLWithPath: binary)
}
