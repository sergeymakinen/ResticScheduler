import SwiftSyntax

extension VariableDeclSyntax {
    var isComputed: Bool {
        guard bindings.count == 1, let accessorBlock = bindings.first?.accessorBlock else {
            return false
        }

        switch accessorBlock.accessors {
        case let .accessors(accessors):
            return accessors.compactMap(\.accessorSpecifier).contains { $0.tokenKind != .keyword(.willSet) && $0.tokenKind != .keyword(.didSet) }
        case .getter:
            return true
        }
    }

    var isInstance: Bool {
        !modifiers.flatMap { $0.tokens(viewMode: .all) }.contains { $0.tokenKind == .keyword(.static) || $0.tokenKind == .keyword(.class) }
    }
}
