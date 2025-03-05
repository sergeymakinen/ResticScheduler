import Foundation
import SwiftUI

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

protocol _Optional {
    static var wrappedType: Any.Type { get }
    
    var isNil: Bool { get }
}

extension Optional: _Optional {
    static var wrappedType: Any.Type { Wrapped.self }
    
    var isNil: Bool { self == nil }
}

func isNil(_ value: some Any) -> Bool {
    return (value as? _Optional)?.isNil == true
}

extension Binding {
    static func optional( _ binding: Binding<Value?>, didSet action: @escaping (() -> Void) = {}) -> Binding<Value> where Value == String {
        return Binding {
            binding.wrappedValue ?? ""
        } set: { newValue in
            binding.wrappedValue = !newValue.isEmpty ? newValue : nil
            action()
        }
    }
}
