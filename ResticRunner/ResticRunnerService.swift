import Foundation
import os
import ResticSchedulerKit

extension Restic {
  var executableURL: URL {
    if let binary, !binary.isEmpty {
      return URL(fileURLWithPath: binary)
    }

    return Bundle.main.url(forResource: "restic", withExtension: "")!
  }
}

extension Process: @unchecked Sendable {}

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

  private static let status = OSAllocatedUnfairLock(initialState: Status.idle)
  private static var process = OSAllocatedUnfairLock<Process?>(initialState: nil)

  private let connection: NSXPCConnection

  init(connection: NSXPCConnection) {
    self.connection = connection
  }

  func version(restic: Restic, reply: @escaping (String?, Error?) -> Void) {
    let process = Process()
    process.qualityOfService = .userInitiated
    process.executableURL = restic.executableURL
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

  func backup(restic: Restic, reply: @escaping (Error?) -> Void) {
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
    process.executableURL = restic.executableURL
    var environment = ProcessInfo.processInfo.environment
    environment["RESTIC_REPOSITORY"] = restic.repository
    environment["RESTIC_PASSWORD"] = restic.password
    environment["RESTIC_PROGRESS_FPS"] = "0.2"
    if let s3AccessKeyId = restic.s3AccessKeyId {
      environment["AWS_ACCESS_KEY_ID"] = s3AccessKeyId
    }
    if let s3SecretAccessKey = restic.s3SecretAccessKey {
      environment["AWS_SECRET_ACCESS_KEY"] = s3SecretAccessKey
    }
    process.environment = environment
    do {
      try FileManager.default.createDirectory(at: restic.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try "\(Date().formatted(.rfc3164)) Starting backup...\n".append(to: restic.logURL, encoding: .utf8)
      let cacheURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
      let supportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
      let includesURL = supportURL.appending(path: "includes", directoryHint: .notDirectory)
      let excludesURL = supportURL.appending(path: "excludes", directoryHint: .notDirectory)
      try restic.includes.joined(separator: "\n").write(to: includesURL, atomically: true, encoding: .utf8)
      try restic.excludes.joined(separator: "\n").write(to: excludesURL, atomically: true, encoding: .utf8)
      process.arguments = [
        "--json",
        "--host", restic.host ?? Host.current().localizedName!,
        "--cache-dir", cacheURL.path(percentEncoded: false), "--cleanup-cache",
        "backup",
      ] + restic.arguments + [
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .map { value in "                \(value)" }
            .joined(separator: "\n")
            .appending("\n")
            .append(to: restic.logURL, encoding: .utf8)
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
            try FileManager.default.createDirectory(at: restic.summaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try summary!.write(to: restic.summaryURL, atomically: true, encoding: .utf8)
          } catch {
            TypeLogger.function().warning("Couldn't write summary: \(error.localizedDescription, privacy: .public)")
          }
        }
        reply(nil)
      } else {
        let error = ProcessError.abnormalTermination(terminationStatus: process.terminationStatus, standardError: standardErrorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        TypeLogger.function().error("\(error.localizedDescription, privacy: .public)")
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
}
