import Combine
import Foundation
import ResticSchedulerKit
import Security

extension String {
  func droppingPrefix(_ prefix: String) -> String {
    if !hasPrefix(prefix) {
      return self
    }

    return String(dropFirst(prefix.count))
  }

  func inserting<C>(contentsOf newElements: C, at i: Index) -> String where C: Collection, Character == C.Element {
    var string = String(stringLiteral: self)
    string.insert(contentsOf: newElements, at: i)
    return string
  }
}

class Model: ObservableObject {
  private var ignoreChanges = false

  var ignoringChanges: Bool { ignoreChanges }

  func ignoringChanges(perform action: () -> Void) {
    let oldValue = ignoreChanges
    ignoreChanges = true
    action()
    ignoreChanges = oldValue
  }
}

protocol _Optional {
  var isNil: Bool { get }
}

extension Optional: _Optional {
  var isNil: Bool { self == nil }
}

func isNil(_ value: some Any) -> Bool { (value as? _Optional)?.isNil == true }

@propertyWrapper struct UserDefault<Value> {
  private let subject = PassthroughSubject<Value, Never>()
  private let defaultValue: Value
  private let key: String
  private let store: UserDefaults

  var projectedValue: AnyPublisher<Value, Never> { subject.eraseToAnyPublisher() }

  var wrappedValue: Value {
    get { getValue() }
    set { setValue(newValue) }
  }

  static subscript<EnclosingSelf>(
    _enclosingInstance instance: EnclosingSelf,
    wrapped _: ReferenceWritableKeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, UserDefault>
  ) -> Value {
    get { instance[keyPath: storageKeyPath].getValue() }
    set {
      let propertyWrapper = instance[keyPath: storageKeyPath]
      propertyWrapper.setValue(newValue)
      propertyWrapper.subject.send(newValue)
      if let observableObject = instance as? any ObservableObject {
        (observableObject.objectWillChange as any Publisher as? ObservableObjectPublisher)?.send()
      }
    }
  }

  init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
    defaultValue = wrappedValue
    self.key = key
    self.store = store
    if !isNil(defaultValue) {
      store.register(defaults: [key: defaultValue])
    }
  }

  init<T>(_ key: String, store: UserDefaults = .standard) where Value == T? {
    self.init(wrappedValue: nil, key, store: store)
  }

  private func getValue() -> Value { store.value(forKey: key) as? Value ?? defaultValue }

  private func setValue(_ value: Value) {
    if isNil(value) {
      store.removeObject(forKey: key)
    } else {
      store.setValue(value, forKey: key)
    }
  }
}

@propertyWrapper struct KeychainPassword {
  private typealias TypeLogger = ResticSchedulerKit.TypeLogger<KeychainPassword>

  private static let service = Bundle.main.bundleIdentifier!

  private let account: String
  private let label: String
  private let queue: DispatchQueue

  var wrappedValue: String {
    get { getValue() }
    set { setValue(newValue) }
  }

  static subscript<EnclosingSelf>(
    _enclosingInstance instance: EnclosingSelf,
    wrapped _: ReferenceWritableKeyPath<EnclosingSelf, String>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, KeychainPassword>
  ) -> String {
    get { instance[keyPath: storageKeyPath].getValue() }
    set {
      instance[keyPath: storageKeyPath].setValue(newValue) {
        if let observableObject = instance as? any ObservableObject {
          (observableObject.objectWillChange as any Publisher as? ObservableObjectPublisher)?.send()
        }
      }
    }
  }

  init(_ account: String, withLabel label: String) {
    self.account = account
    self.label = label
    queue = DispatchQueue(label: "\(Self.service).\(String(describing: KeychainPassword.self)).\(account)")
  }

  init(_ account: String) {
    self.init(account, withLabel: account)
  }

  private func getValue() -> String {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: Self.service,
      kSecAttrAccount: account,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status != errSecItemNotFound else { return "" }
    guard status == errSecSuccess else {
      TypeLogger.function().error("Couldn't get keychain item: \(secErrorMessage(status), privacy: .public)")
      return ""
    }

    return String(data: item as? Data ?? Data(), encoding: .utf8) ?? ""
  }

  private func setValue(_ value: String, completion: @escaping () -> Void = {}) {
    queue.async {
      var query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: Self.service,
        kSecAttrAccount: account,
        kSecAttrLabel: label,
        kSecValueData: value.data(using: .utf8)!,
      ]
      var status = SecItemAdd(query as CFDictionary, nil)
      if status == errSecDuplicateItem {
        let update = [kSecValueData: query[kSecValueData]] as CFDictionary
        query.removeValue(forKey: kSecValueData)
        status = SecItemUpdate(query as CFDictionary, update)
      }
      guard status == errSecSuccess else {
        TypeLogger.function().error("Couldn't set keychain item: \(secErrorMessage(status), privacy: .public)")
        return
      }

      completion()
    }
  }
}

func secErrorMessage(_ status: OSStatus) -> String {
  if let message = SecCopyErrorMessageString(status, nil) {
    return message as String
  }

  return NSError(domain: NSOSStatusErrorDomain, code: Int(status)).localizedDescription
}
