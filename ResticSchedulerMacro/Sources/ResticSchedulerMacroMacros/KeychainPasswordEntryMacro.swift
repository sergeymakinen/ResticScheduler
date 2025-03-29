import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum KeychainPasswordEntryMacroDiagnostic {
    case onSupportedTypesOnly
    case attachOnVarOnly
    case attachOnSimpleVarOnly
    case attachOnStoredPropertyOnly
    case attachOnInstanceMemberOnly
    case missingIdentifier
    case missingDefaultValue
    case missingTypeAnnotation
}

extension KeychainPasswordEntryMacroDiagnostic: DiagnosticMessage {
    func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }

    var message: String {
        switch self {
        case .onSupportedTypesOnly:
            "'@KeychainPasswordEntry' macro can only attach to var declarations inside extensions of KeychainPasswordValues"
        case .attachOnVarOnly:
            "'@KeychainPasswordEntry' can only be applied to a 'var' declaration"
        case .attachOnSimpleVarOnly:
            "'@KeychainPasswordEntry' can only be applied to a 'var' declaration with a simple name"
        case .attachOnStoredPropertyOnly:
            "'@KeychainPasswordEntry' can only be applied to a stored property"
        case .attachOnInstanceMemberOnly:
            "'@KeychainPasswordEntry' cannot be applied to a static member"
        case .missingIdentifier:
            "Expected an identifier for the property"
        case .missingDefaultValue:
            "Property missing a default value"
        case .missingTypeAnnotation:
            "Property missing a type annotation"
        }
    }

    var severity: DiagnosticSeverity { .error }

    var diagnosticID: MessageID { MessageID(domain: "ResticSchedulerMacro", id: "KeychainPasswordEntry.\(self)") }
}

public struct KeychainPasswordEntryMacro {}

extension KeychainPasswordEntryMacro: AccessorMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self), property.bindingSpecifier.tokenKind == .keyword(.var) else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.attachOnVarOnly.diagnose(at: node))
            return []
        }
        guard !property.isComputed else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.attachOnStoredPropertyOnly.diagnose(at: node))
            return []
        }
        guard property.isInstance else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.attachOnInstanceMemberOnly.diagnose(at: node))
            return []
        }
        guard property.bindings.count == 1, let binding = property.bindings.first else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.attachOnSimpleVarOnly.diagnose(at: node))
            return []
        }
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.missingIdentifier.diagnose(at: node))
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

extension KeychainPasswordEntryMacro: PeerMacro {
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
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.missingDefaultValue.diagnose(at: node))
            return []
        }
        guard let valueType = binding.typeAnnotation?.type.trimmed else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.missingTypeAnnotation.diagnose(at: node))
            return []
        }
        guard context.lexicalContext.contains(where: { $0.as(ExtensionDeclSyntax.self)?.extendedType.trimmedDescription == "KeychainPasswordValues" }) else {
            context.diagnose(KeychainPasswordEntryMacroDiagnostic.onSupportedTypesOnly.diagnose(at: node))
            return []
        }
        guard case let .argumentList(arguments) = node.arguments, let label = arguments.first else {
            return []
        }

        return try [
            DeclSyntax(StructDeclSyntax("private struct __Key_\(identifier): KeychainPasswordKey") {
                DeclSyntax("static var label = \(label.expression)")
                DeclSyntax("static var defaultValue: \(valueType) = \(initializer)")
                if let account = arguments.first(where: { $0.label?.text == "forAccount" }) {
                    DeclSyntax("static var account = \(account.expression)")
                }
            }),
        ]
    }
}
