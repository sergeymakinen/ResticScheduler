import Foundation
import os
import SwiftUI

protocol UserDefaultObjectRepresentable: Equatable {
    init?(userDefaultObject value: Any)

    func userDefaultObject() -> Any?
}

protocol UserDefaultKey {
    associatedtype Value

    static var key: String { get }
    static var defaultValue: Value { get }
    static var store: UserDefaults { get }
}

extension UserDefaultKey {
    static var store: UserDefaults { .standard }
}

struct UserDefaultValues {
    fileprivate class Storage {
        fileprivate class Value<Value>: ObservableObject {
            var value: Value {
                get {
                    lock.withLock { [weak self, key] in
                        guard let self else {
                            return key.defaultValue as! Value
                        }
                        guard !isRead else {
                            return _value
                        }

                        if !isNil(_value) {
                            key.store.register(defaults: [key.key: _value])
                        }
                        if let value = key.store.object(forKey: key.key) {
                            var type: Any.Type = Value.self
                            if let optionalType = Value.self as? _Optional.Type {
                                type = optionalType.wrappedType
                            }
                            if let representableType = type as? any UserDefaultObjectRepresentable.Type, let value = representableType.init(userDefaultObject: value) as? Value {
                                _value = value
                            } else if let value = value as? Value {
                                _value = value
                            }
                        }
                        isRead = true
                        return _value
                    }
                }
                set {
                    lock.withLock { [weak self] in
                        guard let self else {
                            return
                        }

                        if shouldSendObjectWillChange(newValue) {
                            objectWillChange.send()
                        }
                        let value: Any? = if let representableValue = newValue as? any UserDefaultObjectRepresentable {
                            representableValue.userDefaultObject()
                        } else {
                            newValue
                        }
                        if value != nil {
                            key.store.set(value, forKey: key.key)
                            _value = newValue
                        } else {
                            key.store.removeObject(forKey: key.key)
                            _value = key.defaultValue as! Value
                        }
                        isRead = true
                    }
                }
            }

            private let lock = OSAllocatedUnfairLock()
            private let key: any UserDefaultKey.Type
            private var _value: Value

            private var isRead = false

            init<K>(key: K.Type) where K: UserDefaultKey, K.Value == Value {
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

        var keys: [PartialKeyPath<UserDefaultValues>: any UserDefaultKey.Type] = [:]
        var values: [ObjectIdentifier: Any] = [:]
    }

    fileprivate let storage = Storage()
    private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(UserDefaultValues.self)", qos: .userInitiated, attributes: .concurrent)

    subscript<K>(key: K.Type) -> K.Value where K: UserDefaultKey {
        get { queue.sync(flags: .barrier) { self[key].value }}
        set { queue.sync(flags: .barrier) { self[key].value = newValue }}
    }

    subscript<K>(key: K.Type, registeringKeyPath keyPath: KeyPath<UserDefaultValues, K.Value>) -> K.Value where K: UserDefaultKey {
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

    private subscript<K>(key: K.Type) -> Storage.Value<K.Value> where K: UserDefaultKey {
        if storage.values[ObjectIdentifier(K.self)] == nil {
            storage.values[ObjectIdentifier(K.self)] = Storage.Value(key: key)
        }
        return storage.values[ObjectIdentifier(K.self)]! as! UserDefaultValues.Storage.Value<K.Value>
    }
}

fileprivate var userDefaultValues = UserDefaultValues()

@propertyWrapper struct UserDefault<Value>: DynamicProperty {
    @StateObject private var value: UserDefaultValues.Storage.Value<Value>
    private let keyPath: KeyPath<UserDefaultValues, Value>

    var wrappedValue: Value {
        get { userDefaultValues[keyPath: keyPath] }
        nonmutating set { userDefaultValues[keyPath: keyPath as! WritableKeyPath<UserDefaultValues, Value>] = newValue }
    }

    var projectedValue: Binding<Value> {
        Binding {
            wrappedValue
        } set: { newValue in
            wrappedValue = newValue
        }
    }

    init(_ keyPath: KeyPath<UserDefaultValues, Value>) {
        self.keyPath = keyPath
        let key = userDefaultValues.storage.keys[keyPath]
        if key == nil {
            _ = userDefaultValues[keyPath: keyPath]
        }
        guard let key = userDefaultValues.storage.keys[keyPath], let value = userDefaultValues.storage.values[ObjectIdentifier(key)] as? UserDefaultValues.Storage.Value<Value> else {
            fatalError("\(keyPath) is not registered with UserDefaultValues.subscript(_:registeringKeyPath:)")
        }

        _value = StateObject(wrappedValue: value)
    }
}
