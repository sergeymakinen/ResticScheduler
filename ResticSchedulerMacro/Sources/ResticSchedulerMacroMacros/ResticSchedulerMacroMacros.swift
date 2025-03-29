import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ResticSchedulerMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        UserDefaultEntryMacro.self,
        KeychainPasswordEntryMacro.self,
    ]
}
