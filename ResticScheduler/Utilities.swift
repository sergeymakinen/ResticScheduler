import Foundation

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

@available(*, deprecated, message: "Use property wrappers directly in views")
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
    static var wrappedType: Any.Type { get }
    var isNil: Bool { get }
}

extension Optional: _Optional {
    static var wrappedType: Any.Type { Wrapped.self }
    var isNil: Bool { self == nil }
}

func isNil(_ value: some Any) -> Bool { (value as? _Optional)?.isNil == true }
