import Foundation
import os
import SwiftUI

protocol UserDefaultObjectRepresentable {
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
                        guard let self, shouldChange(newValue) else {
                            return
                        }

                        objectWillChange.send()
                        let value: Any? = if let representableValue = newValue as? any UserDefaultObjectRepresentable {
                            representableValue.userDefaultObject()
                        } else {
                            newValue
                        }
                        if let value, !isNil(value) {
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

            init(key: any UserDefaultKey.Type) {
                self.key = key
                _value = key.defaultValue as! Value
            }

            private func shouldChange(_: Value) -> Bool {
                true
            }

            private func shouldChange(_ newValue: Value) -> Bool where Value: Equatable {
                newValue != _value
            }
        }

        var keys = OSAllocatedUnfairLock<[PartialKeyPath<UserDefaultValues>: any UserDefaultKey.Type]>(initialState: [:])
        var values = OSAllocatedUnfairLock<[ObjectIdentifier: Any]>(initialState: [:])

        subscript<T>(key: any UserDefaultKey.Type) -> Value<T> {
            values.withLock { value in
                if value[ObjectIdentifier(key)] == nil {
                    value[ObjectIdentifier(key)] = Value<T>(key: key)
                }
                return value[ObjectIdentifier(key)]! as! Value<T>
            }
        }
    }

    static var shared = UserDefaultValues()

    fileprivate let storage = Storage()

    private init() {}

    subscript<K>(key: K.Type) -> K.Value where K: UserDefaultKey {
        get { storage[key].value }
        nonmutating set { storage[key].value = newValue }
    }

    subscript<K>(key: K.Type, forKeyPath keyPath: KeyPath<UserDefaultValues, K.Value>) -> K.Value where K: UserDefaultKey {
        get {
            storage.keys.withLock { value in value[keyPath] = key }
            return self[key]
        }
        nonmutating set {
            storage.keys.withLock { value in value[keyPath] = key }
            self[key] = newValue
        }
    }
}

extension UserDefaultValues.Storage.Value: @unchecked Sendable where Value: Sendable {}

@propertyWrapper struct UserDefault<Value>: DynamicProperty {
    @StateObject private var value: UserDefaultValues.Storage.Value<Value>
    private let keyPath: KeyPath<UserDefaultValues, Value>

    var wrappedValue: Value {
        get { UserDefaultValues.shared[keyPath: keyPath] }
        nonmutating set { UserDefaultValues.shared[keyPath: keyPath as! WritableKeyPath<UserDefaultValues, Value>] = newValue }
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
        var key = UserDefaultValues.shared.storage.keys.withLock { value in value[keyPath] }
        if key == nil {
            _ = UserDefaultValues.shared[keyPath: keyPath]
            key = UserDefaultValues.shared.storage.keys.withLock { value in value[keyPath] }
        }
        guard let key else {
            fatalError("\(keyPath) is not registered with UserDefaultValues.subscript(_:forKeyPath:)")
        }

        _value = StateObject(wrappedValue: UserDefaultValues.shared.storage[key])
    }
}
