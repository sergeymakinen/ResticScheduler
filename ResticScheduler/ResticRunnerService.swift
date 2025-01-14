import Foundation
import ResticSchedulerKit

class ResticRunnerService: ResticRunnerProtocol {
  static let shared = ResticRunnerService()

  private static let serviceName = Bundle.main.object(forInfoDictionaryKey: "APP_RESTIC_RUNNER_SERVICE_NAME") as! String

  private init() {}

  func version(restic: Restic, reply: @escaping (String?, Error?) -> Void) {
    let replyOnce = withCallingReplyOnce(reply)
    activateRemoteObjectProxyWithErrorHandler { error in replyOnce(nil, error) }?.version(restic: restic, reply: replyOnce)
  }

  func backup(restic: Restic, reply: @escaping (Error?) -> Void) {
    let replyOnce = withCallingReplyOnce(reply)
    activateRemoteObjectProxyWithErrorHandler(exporting: ResticSchedulerProtocol.self, via: ResticScheduler.shared) { error in replyOnce(error) }?.backup(restic: restic, reply: replyOnce)
  }

  func stop(reply: @escaping (Error?) -> Void) {
    let replyOnce = withCallingReplyOnce(reply)
    activateRemoteObjectProxyWithErrorHandler(exporting: ResticSchedulerProtocol.self, via: ResticScheduler.shared) { error in replyOnce(error) }?.stop(reply: replyOnce)
  }

  private func activateRemoteObjectProxyWithErrorHandler(_ handler: @escaping (XPCConnectionError) -> Void) -> ResticRunnerProtocol? {
    NSXPCConnection(serviceName: Self.serviceName).activateRemoteObjectProxyWithErrorHandler(protocol: ResticRunnerProtocol.self) { error in handler(error) }
  }

  private func activateRemoteObjectProxyWithErrorHandler(exporting protocol: Protocol, via object: Any, handler: @escaping (XPCConnectionError) -> Void) -> ResticRunnerProtocol? {
    let connection = NSXPCConnection(serviceName: Self.serviceName)
    connection.exportedInterface = NSXPCInterface(with: `protocol`)
    connection.exportedObject = object
    return connection.activateRemoteObjectProxyWithErrorHandler(protocol: ResticRunnerProtocol.self) { error in handler(error) }
  }
}

extension Restic {
  static func environment() -> Restic {
    Restic(
      repository: AppEnvironment.shared.resticRepository,
      s3AccessKeyId: AppEnvironment.shared.s3AccessKeyId,
      s3SecretAccessKey: AppEnvironment.shared.s3SecretAccessKey,
      restUsername: AppEnvironment.shared.restUsername,
      restPassword: AppEnvironment.shared.restPassword,
      password: AppEnvironment.shared.resticPassword,
      host: AppEnvironment.shared.resticHost,
      binary: AppEnvironment.shared.resticBinary,
      arguments: AppEnvironment.shared.resticArguments,
      includes: AppEnvironment.shared.resticIncludes,
      excludes: AppEnvironment.shared.resticExcludes,
      logURL: AppEnvironment.shared.logURL,
      summaryURL: AppEnvironment.shared.summaryURL
    )
  }
}
