import Foundation
import os
import ResticSchedulerKit
import SwiftUI

protocol DataRepresentable {
    init?(data: Data)

    func data() -> Data?
}

extension String: DataRepresentable {
    init?(data: Data) {
        self.init(data: data, encoding: .utf8)
    }

    func data() -> Data? {
        data(using: .utf8)
    }
}

extension String?: DataRepresentable {
    init?(data: Data) {
        self = String(data: data, encoding: .utf8)
    }

    func data() -> Data? {
        self?.data(using: .utf8)
    }
}

protocol KeychainPasswordKey {
    associatedtype Value: DataRepresentable

    static var label: String { get }
    static var account: String? { get }
    static var defaultValue: Value { get }
}

extension KeychainPasswordKey {
    static var account: String? { nil }

    fileprivate static var query: [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Bundle.main.bundleIdentifier!,
            kSecAttrLabel: label,
        ]
        if let account {
            query[kSecAttrAccount] = account
        }
        return query
    }
}

struct KeychainPasswordValues {
    fileprivate class Storage {
        fileprivate class Value<Value: DataRepresentable>: ObservableObject {
            private typealias TypeLogger = ResticSchedulerKit.TypeLogger<KeychainPasswordValues.Storage.Value<Value>>

            var value: Value {
                get {
                    lock.withLock { [weak self, key] in
                        guard let self else {
                            return key.defaultValue as! Value
                        }
                        guard !isRead else {
                            return _value
                        }

                        let query = key.query.merging([
                            kSecReturnData: true,
                            kSecMatchLimit: kSecMatchLimitOne,
                        ]) { _, new in new }
                        var item: CFTypeRef?
                        let status = SecItemCopyMatching(query as CFDictionary, &item)
                        switch status {
                        case errSecSuccess:
                            if let data = item as? Data, let value = Value(data: data) {
                                _value = value
                            }
                            isRead = true
                        case errSecItemNotFound:
                            isRead = true
                        default:
                            TypeLogger.function().error("Couldn't get keychain item: \(secErrorMessage(status), privacy: .public)")
                        }
                        return _value
                    }
                }
                set {
                    lock.withLock { [weak self] in
                        guard let self else {
                            return
                        }

                        queue.async { [weak self] in
                            guard let self else {
                                return
                            }

                            if shouldSendObjectWillChange(newValue) {
                                objectWillChange.send()
                            }
                            let data = newValue.data()
                            let query = key.query
                            var status: OSStatus
                            if let data {
                                let update = [kSecValueData: data]
                                status = SecItemAdd(query.merging(update) { _, new in new } as CFDictionary, nil)
                                if status == errSecDuplicateItem {
                                    status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
                                }
                            } else {
                                status = SecItemDelete(query as CFDictionary)
                            }
                            guard status == errSecSuccess else {
                                TypeLogger.function().error("Couldn't \(isNil(newValue) ? "delete" : "set") keychain item: \(secErrorMessage(status), privacy: .public)")
                                return
                            }

                            _value = data != nil ? newValue : key.defaultValue as! Value
                            isRead = true
                        }
                    }
                }
            }

            private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(Value.self)", qos: .userInitiated, attributes: .concurrent)
            private let lock = OSAllocatedUnfairLock()
            private let key: any KeychainPasswordKey.Type
            private var _value: Value
            private var isRead = false

            init<K>(key: K.Type) where K: KeychainPasswordKey, K.Value == Value {
                self.key = key
                _value = key.defaultValue
            }

            private func shouldSendObjectWillChange(_: Value) -> Bool {
                true
            }

            private func shouldSendObjectWillChange(_ newValue: Value) -> Bool where Value: Equatable {
                newValue != _value
            }
        }

        var keys: [PartialKeyPath<KeychainPasswordValues>: any KeychainPasswordKey.Type] = [:]
        var values: [ObjectIdentifier: Any] = [:]
    }

    fileprivate let storage = Storage()
    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(KeychainPasswordValues.self)", qos: .userInitiated, attributes: .concurrent)

    subscript<K>(key: K.Type) -> K.Value where K: KeychainPasswordKey {
        get { queue.sync(flags: .barrier) { self[key].value }}
        set { queue.sync(flags: .barrier) { self[key].value = newValue }}
    }

    subscript<K>(key: K.Type, registeringKeyPath keyPath: KeyPath<KeychainPasswordValues, K.Value>) -> K.Value where K: KeychainPasswordKey {
        get {
            queue.sync(flags: .barrier) {
                storage.keys[keyPath] = key
                return self[key].value
            }
        }
        set {
            queue.sync(flags: .barrier) {
                storage.keys[keyPath] = key
                self[key].value = newValue
            }
        }
    }

    private subscript<K>(key: K.Type) -> Storage.Value<K.Value> where K: KeychainPasswordKey {
        if storage.values[ObjectIdentifier(K.self)] == nil {
            storage.values[ObjectIdentifier(K.self)] = Storage.Value(key: key)
        }
        return storage.values[ObjectIdentifier(K.self)]! as! KeychainPasswordValues.Storage.Value<K.Value>
    }
}

fileprivate var keychainPasswordValues = KeychainPasswordValues()

@propertyWrapper struct KeychainPassword<Value: DataRepresentable>: DynamicProperty {
    @StateObject private var value: KeychainPasswordValues.Storage.Value<Value>
    private let keyPath: KeyPath<KeychainPasswordValues, Value>

    var wrappedValue: Value {
        get { keychainPasswordValues[keyPath: keyPath] }
        nonmutating set { keychainPasswordValues[keyPath: keyPath as! WritableKeyPath<KeychainPasswordValues, Value>] = newValue }
    }

    var projectedValue: Binding<Value> {
        Binding {
            wrappedValue
        } set: { newValue in
            wrappedValue = newValue
        }
    }

    init(_ keyPath: KeyPath<KeychainPasswordValues, Value>) {
        self.keyPath = keyPath
        let key = keychainPasswordValues.storage.keys[keyPath]
        if key == nil {
            _ = keychainPasswordValues[keyPath: keyPath]
        }
        guard let key = keychainPasswordValues.storage.keys[keyPath], let value = keychainPasswordValues.storage.values[ObjectIdentifier(key)] as? KeychainPasswordValues.Storage.Value<Value> else {
            fatalError("\(keyPath) is not registered with KeychainPasswordValues.subscript(_:registeringKeyPath:)")
        }

        _value = StateObject(wrappedValue: value)
    }
}

func secErrorMessage(_ status: OSStatus) -> String {
    if let message = SecCopyErrorMessageString(status, nil) {
        return message as String
    }

    return NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription
}
