import Foundation

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro UserDefaultEntry(_ key: String) = #externalMacro(module: "ResticSchedulerMacroMacros", type: "UserDefaultEntryMacro")

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro UserDefaultEntry(_ key: String, inStore store: UserDefaults) = #externalMacro(module: "ResticSchedulerMacroMacros", type: "UserDefaultEntryMacro")

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro KeychainPasswordEntry(_ label: String) = #externalMacro(module: "ResticSchedulerMacroMacros", type: "KeychainPasswordEntryMacro")

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro KeychainPasswordEntry(_ label: String, forAccount account: String) = #externalMacro(module: "ResticSchedulerMacroMacros", type: "KeychainPasswordEntryMacro")
