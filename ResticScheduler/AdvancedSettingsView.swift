import os
import ResticSchedulerKit
import SwiftUI

struct AdvancedSettingsView: View {
    private enum BinaryType {
        case manual, builtIn, browse
    }

    private enum HostType {
        case custom, system
    }

    private class BinaryVersion: ObservableObject {
        var value: String? { version ?? error?.localizedDescription }

        var isError: Bool? {
            guard version != nil || error != nil else {
                return nil
            }

            return error != nil
        }

        @Published private var version: String?
        @Published private var error: Error?

        private let queue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier!).\(BinaryVersion.self)", qos: .userInitiated)
        private var binary: String?

        func scheduleUpdate(via resticScheduler: ResticScheduler, for binary: String?) {
            queue.async {
                guard (self.version == nil && self.error == nil) || binary != self.binary else {
                    return
                }

                resticScheduler.version { [weak self] version, error in
                    DispatchQueue.main.sync {
                        self?.binary = binary
                        self?.version = version
                        self?.error = error
                    }
                }
            }
        }
    }

    @State private var browseBinary = false
    @StateObject private var binaryVersion = BinaryVersion()
    @EnvironmentObject private var resticScheduler: ResticScheduler
    @UserDefault(\.binary) private var binary
    @UserDefault(\.host) private var host
    @UserDefault(\.arguments) private var arguments
    @UserDefault(\.beforeBackupHook) private var beforeBackupHook
    @UserDefault(\.onSuccessHook) private var onSuccessHook
    @UserDefault(\.onFailureHook) private var onFailureHook

    private var image: NSImage {
        let image = NSWorkspace.shared.icon(forFile: binary!)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    var body: some View {
        VStack {
            Form {
                Section {
                    let binaryType = Binding<BinaryType> {
                        binary == nil ? .builtIn : .manual
                    } set: { newValue in
                        switch newValue {
                        case .builtIn:
                            binary = nil
                        case .browse:
                            browseBinary = true
                        default:
                            break
                        }
                    }

                    Picker("Restic:", selection: binaryType) {
                        if let binary, !binary.isEmpty {
                            HStack {
                                Image(nsImage: image)
                                Text(FileManager.default.displayName(atPath: binary))
                            }
                            .tag(BinaryType.manual)
                            Divider()
                        }
                        Text("Built-in")
                            .tag(BinaryType.builtIn)
                        Text("Other…")
                            .tag(BinaryType.browse)
                    }
                    .padding(.bottom, binaryVersion.value == nil ? 10 : 0)
                    .fileImporter(isPresented: $browseBinary, allowedContentTypes: [.shellScript, .unixExecutable], onCompletion: { result in
                        binary = try! result.get().path(percentEncoded: false)
                    })
                } footer: {
                    HStack(alignment: .top, spacing: 5) {
                        if let value = binaryVersion.value {
                            if binaryVersion.isError == true {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text(value)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .help(value)
                                .textSelection(.enabled)
                            Spacer()
                        }
                    }
                }
                HStack {
                    let hostType = Binding<HostType> {
                        host == nil ? .system : .custom
                    } set: { newValue in
                        switch newValue {
                        case .system:
                            host = nil
                        case .custom:
                            if host == nil {
                                host = Host.current().localizedName!
                            }
                        }
                    }

                    Picker("Hostname:", selection: hostType) {
                        Text("System")
                            .tag(HostType.system)
                        Text("Custom")
                            .tag(HostType.custom)
                    }
                    .frame(maxWidth: 170)
                    let hostName = Binding<String> {
                        host ?? Host.current().localizedName!
                    } set: { newValue in
                        host = newValue
                    }

                    TextField("Name:", text: hostName)
                        .labelsHidden()
                        .disabled(hostType.wrappedValue == .system)
                }
                EditableList("Arguments:", values: $arguments, isBrowseable: false)
                    .padding(.bottom)
                HookEditor("Before backup:", hook: $beforeBackupHook, hooks: [beforeBackupHook, onSuccessHook, onFailureHook])
                HookEditor("On success:", hook: $onSuccessHook, hooks: [beforeBackupHook, onSuccessHook, onFailureHook])
                HookEditor("On failure:", hook: $onFailureHook, hooks: [beforeBackupHook, onSuccessHook, onFailureHook])
            }
            .frame(width: 400, alignment: .center)
            .padding()
        }
        .onChange(of: [
            binary,
            host,
            arguments,
        ] as [AnyHashable]) { _ in resticScheduler.rescheduleStaleBackupCheck() }
        .onChange(of: binary) { _ in binaryVersion.scheduleUpdate(via: resticScheduler, for: binary) }
        .onAppear { binaryVersion.scheduleUpdate(via: resticScheduler, for: binary) }
    }
}

#Preview {
    AdvancedSettingsView()
}
