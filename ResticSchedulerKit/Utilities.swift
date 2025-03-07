import Foundation
import os

public enum XPCConnectionError: LocalizedError {
    case connectionInterrupted
    case connectionInvalidated
    case invalidRemoteObject
    case remoteMessageFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .connectionInterrupted: "XPC connection interrupted"
        case .connectionInvalidated: "XPC connection invalidated"
        case .invalidRemoteObject: "Invalid XPC remote object"
        case let .remoteMessageFailed(error): "XPC remote message failed: \(error.localizedDescription)"
        }
    }
}

class Once: Hashable {
    private static var pending = OSAllocatedUnfairLock(initialState: Set<Once>())

    private let id = UUID()
    private var happened = OSAllocatedUnfairLock(initialState: false)

    static func == (lhs: Once, rhs: Once) -> Bool { lhs.id == rhs.id }

    init() {
        Self.pending.withLock { value in _ = value.insert(self) }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func happen() -> Bool {
        happened.withLock { value in
            if !value {
                value = true
                Self.pending.withLock { value in _ = value.remove(self) }
                return true
            }

            return false
        }
    }
}

public func withCallingReplyOnce<Result, Error>(_ reply: @escaping (Result, Error) -> Void, function: StaticString = #function) -> (Result, Error) -> Void {
    let once = Once()
    return { [weak once] result, error in
        if once?.happen() == true {
            reply(result, error)
            return
        }

        Logger.function().warning("Ignored subsequent call at \(function)")
    }
}

public func withCallingReplyOnce<Error>(_ reply: @escaping (Error) -> Void, function: StaticString = #function) -> (Error) -> Void {
    let once = Once()
    return { [weak once] error in
        if once?.happen() == true {
            reply(error)
            return
        }

        Logger.function().warning("Ignored subsequent call at \(function)")
    }
}

public extension NSXPCConnection {
    func activateRemoteObjectProxyWithErrorHandler<T>(protocol: Protocol, with handler: @escaping (XPCConnectionError) -> Void) -> T? {
        remoteObjectInterface = NSXPCInterface(with: `protocol`)
        interruptionHandler = { handler(.connectionInterrupted) }
        invalidationHandler = { handler(.connectionInvalidated) }
        activate()
        if let proxy = remoteObjectProxyWithErrorHandler({ error in handler(.remoteMessageFailed(error)) }) as? T {
            return proxy
        }

        handler(.invalidRemoteObject)
        return nil
    }
}

public extension Logger {
    static func function(_ function: StaticString = #function) -> Self {
        Self(subsystem: Bundle.main.bundleIdentifier!, category: "\(function)")
    }
}

public enum TypeLogger<T> {
    public static func function(_ function: StaticString = #function) -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier!, category: "\(String(describing: T.self)).\(function)")
    }
}
