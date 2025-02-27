import SwiftUI

struct HookEditor: View {
    private enum HookType: Equatable, Hashable, Identifiable, CustomStringConvertible {
        case script(path: String)
        case browse

        var id: String {
            switch self {
            case let .script(path): path
            default: ""
            }
        }

        var description: String {
            switch self {
            case let .script(path):
                let url = URL(fileURLWithPath: path)
                return "\(url.lastPathComponent) — \((url.deletingLastPathComponent().path(percentEncoded: false) as NSString).standardizingPath)"
            default:
                return ""
            }
        }
    }

    @State private var browse = false

    private let title: any StringProtocol
    private let hook: Binding<Hook?>
    private let hooks: [Hook?]
    private let sources: [HookType]

    var body: some View {
        LabeledContent {
            let enabled = Binding<Bool> {
                hook.wrappedValue?.enabled ?? false
            } set: { newValue in
                hook.wrappedValue = .init(enabled: newValue, path: hook.wrappedValue?.path ?? "")
            }

            HStack {
                Toggle("Run", isOn: enabled)
                let hookType = Binding<HookType> {
                    guard let path = hook.wrappedValue?.path, !path.isEmpty else {
                        return .browse
                    }

                    return .script(path: path)
                } set: { newValue in
                    switch newValue {
                    case let .script(path):
                        hook.wrappedValue = .init(enabled: enabled.wrappedValue, path: path)
                    case .browse:
                        browse = true
                    }
                }

                Picker("Script", selection: hookType) {
                    ForEach(sources) { source in
                        Text(String(describing: source))
                            .tag(source)
                    }
                    if !sources.isEmpty {
                        Divider()
                    }
                    Text("Choose Script…")
                        .tag(HookType.browse)
                }
                .labelsHidden()
                .disabled(!enabled.wrappedValue)
                .fileImporter(isPresented: $browse, allowedContentTypes: [.unixExecutable, .shellScript], onCompletion: { result in
                    hook.wrappedValue = .init(enabled: enabled.wrappedValue, path: try! result.get().path(percentEncoded: false))
                })
            }
        } label: {
            Text(title)
                .offset(y: 1)
        }
    }

    init(_ title: some StringProtocol, hook: Binding<Hook?>, hooks: [Hook?] = []) {
        self.title = title
        self.hook = hook
        self.hooks = hooks
        sources = Array(Set((hooks + [hook.wrappedValue]).compactMap { $0 }.filter { !$0.path.isEmpty }.map { hook in .script(path: hook.path) }))
    }
}

struct Hook: Codable {
    let enabled: Bool
    let path: String
    
    init?(enabled: Bool, path: String) {
        guard enabled || !path.isEmpty else {
            return nil
        }
        
        self.enabled = enabled
        self.path = path
    }
}

extension Hook: UserDefaultObjectRepresentable {
    init?(userDefaultObject value: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        guard let object = try? JSONDecoder().decode(Hook.self, from: data) else {
            return nil
        }

        self = object
    }

    func userDefaultObject() -> Any? {
        guard enabled || !path.isEmpty else {
            return nil
        }
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }
}

#Preview {
    HookEditor("Title", hook: .constant(.init(enabled: true, path: "/foo/bar.sh")), hooks: [.init(enabled: false, path: "/baz/qux.sh")])
}
