import Foundation
import ResticSchedulerKit

class ResticRunner: ResticRunnerProtocol {
    private static let serviceName = Bundle.main.object(forInfoDictionaryKey: "APP_RESTIC_RUNNER_SERVICE_NAME") as! String

    func version(binary: String?, reply: @escaping (String?, Error?) -> Void) {
        let replyOnce = withCallingReplyOnce(reply)
        activateRemoteObjectProxyWithErrorHandler { error in replyOnce(nil, error) }?.version(binary: binary, reply: replyOnce)
    }

    func backup(restic: Restic, reply: @escaping (Error?) -> Void) {
        let replyOnce = withCallingReplyOnce(reply)
        activateRemoteObjectProxyWithErrorHandler(exporting: ResticSchedulerProtocol.self) { error in replyOnce(error) }?.backup(restic: restic, reply: replyOnce)
    }

    func stop(reply: @escaping (Error?) -> Void) {
        let replyOnce = withCallingReplyOnce(reply)
        activateRemoteObjectProxyWithErrorHandler(exporting: ResticSchedulerProtocol.self) { error in replyOnce(error) }?.stop(reply: replyOnce)
    }

    private func activateRemoteObjectProxyWithErrorHandler(_ handler: @escaping (XPCConnectionError) -> Void) -> ResticRunnerProtocol? {
        NSXPCConnection(serviceName: Self.serviceName).activateRemoteObjectProxyWithErrorHandler(protocol: ResticRunnerProtocol.self) { error in handler(error) }
    }

    private func activateRemoteObjectProxyWithErrorHandler(exporting protocol: Protocol, handler: @escaping (XPCConnectionError) -> Void) -> ResticRunnerProtocol? {
        let connection = NSXPCConnection(serviceName: Self.serviceName)
        connection.exportedInterface = NSXPCInterface(with: `protocol`)
        connection.exportedObject = self
        return connection.activateRemoteObjectProxyWithErrorHandler(protocol: ResticRunnerProtocol.self) { error in handler(error) }
    }
}
