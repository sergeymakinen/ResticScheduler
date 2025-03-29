import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum UserDefaultEntryMacroDiagnostic {
    case onSupportedTypesOnly
    case attachOnVarOnly
    case attachOnSimpleVarOnly
    case attachOnStoredPropertyOnly
    case attachOnInstanceMemberOnly
    case missingIdentifier
    case missingDefaultValue
    case missingTypeAnnotation
}

extension UserDefaultEntryMacroDiagnostic: DiagnosticMessage {
    func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }

    var message: String {
        switch self {
        case .onSupportedTypesOnly:
            "'@UserDefaultEntry' macro can only attach to var declarations inside extensions of UserDefaultValues"
        case .attachOnVarOnly:
            "'@UserDefaultEntry' can only be applied to a 'var' declaration"
        case .attachOnSimpleVarOnly:
            "'@UserDefaultEntry' can only be applied to a 'var' declaration with a simple name"
        case .attachOnStoredPropertyOnly:
            "'@UserDefaultEntry' can only be applied to a stored property"
        case .attachOnInstanceMemberOnly:
            "'@UserDefaultEntry' cannot be applied to a static member"
        case .missingIdentifier:
            "Expected an identifier for the property"
        case .missingDefaultValue:
            "Property missing a default value"
        case .missingTypeAnnotation:
            "Property missing a type annotation"
        }
    }

    var severity: DiagnosticSeverity { .error }

    var diagnosticID: MessageID { MessageID(domain: "ResticSchedulerMacro", id: "UserDefaultEntry.\(self)") }
}

public struct UserDefaultEntryMacro {}

extension UserDefaultEntryMacro: AccessorMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self), property.bindingSpecifier.tokenKind == .keyword(.var) else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.attachOnVarOnly.diagnose(at: node))
            return []
        }
        guard !property.isComputed else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.attachOnStoredPropertyOnly.diagnose(at: node))
            return []
        }
        guard property.isInstance else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.attachOnInstanceMemberOnly.diagnose(at: node))
            return []
        }
        guard property.bindings.count == 1, let binding = property.bindings.first else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.attachOnSimpleVarOnly.diagnose(at: node))
            return []
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.missingIdentifier.diagnose(at: node))
            return []
        }

        return [
            """
            get {
                self[__Key_\(identifier).self, forKeyPath: \\.\(identifier)]
            }
            set {
                self[__Key_\(identifier).self, forKeyPath: \\.\(identifier)] = newValue
            }
            """,
        ]
    }
}

extension UserDefaultEntryMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self), property.bindingSpecifier.tokenKind == .keyword(.var) else {
            return []
        }
        guard property.bindings.count == 1, let binding = property.bindings.first else {
            return []
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed else {
            return []
        }
        guard let initializer = binding.initializer?.value.trimmed else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.missingDefaultValue.diagnose(at: node))
            return []
        }
        guard let valueType = binding.typeAnnotation?.type.trimmed else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.missingTypeAnnotation.diagnose(at: node))
            return []
        }
        guard context.lexicalContext.contains(where: { $0.as(ExtensionDeclSyntax.self)?.extendedType.trimmedDescription == "UserDefaultValues" }) else {
            context.diagnose(UserDefaultEntryMacroDiagnostic.onSupportedTypesOnly.diagnose(at: node))
            return []
        }
        guard case let .argumentList(arguments) = node.arguments, let key = arguments.first else {
            return []
        }

        return try [
            DeclSyntax(StructDeclSyntax("private struct __Key_\(identifier): UserDefaultKey") {
                DeclSyntax("static var key = \(key.expression)")
                DeclSyntax("static var defaultValue: \(valueType) = \(initializer)")
                if let store = arguments.first(where: { $0.label?.text == "inStore" }) {
                    DeclSyntax("static var store: UserDefaults = \(store.expression)")
                }
            }),
        ]
    }
}
