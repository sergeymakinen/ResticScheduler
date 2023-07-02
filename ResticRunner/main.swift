import Foundation
import ResticSchedulerKit

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
  func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
    newConnection.exportedInterface = NSXPCInterface(with: ResticRunnerProtocol.self)
    newConnection.exportedObject = ResticRunnerService(connection: newConnection)
    newConnection.resume()
    return true
  }
}

let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
