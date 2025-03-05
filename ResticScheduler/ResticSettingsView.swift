import SwiftUI

enum RepositoryType: String {
    case local
    case sftp = "sftp:"
    case rest = "rest:"
    case s3 = "s3:"
    case browse

    var hasAddress: Bool {
        switch self {
        case .local, .browse:
            false
        case .sftp, .rest, .s3:
            true
        }
    }
}

struct ResticSettingsView: View {
    @State private var browseRepository = false
    @EnvironmentObject private var resticScheduler: ResticScheduler
    @UserDefault(\.lastSuccessfulBackupDate) private var lastSuccessfulBackupDate
    @UserDefault(\.repository) private var repository
    @KeychainPassword(\.password) private var password
    @UserDefault(\.includes) private var includes
    @UserDefault(\.excludes) private var excludes
    @UserDefault(\.s3AccessKeyId) private var s3AccessKeyId
    @KeychainPassword(\.s3SecretAccessKey) private var s3SecretAccessKey
    @UserDefault(\.restUsername) private var restUsername
    @KeychainPassword(\.restPassword) private var restPassword

    private var image: NSImage {
        let image = NSWorkspace.shared.icon(forFile: repository)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    var body: some View {
        VStack {
            Form {
                let repositoryType = Binding<RepositoryType> {
                    switch true {
                    case repository.hasPrefix(RepositoryType.sftp.rawValue):
                        .sftp
                    case repository.hasPrefix(RepositoryType.rest.rawValue):
                        .rest
                    case repository.hasPrefix(RepositoryType.s3.rawValue):
                        .s3
                    default:
                        .local
                    }
                } set: { newValue in
                    guard newValue != .browse else {
                        browseRepository = true
                        return
                    }

                    switch newValue {
                    case .sftp:
                        repository = RepositoryType.sftp.rawValue
                    case .rest:
                        repository = RepositoryType.rest.rawValue
                    case .s3:
                        repository = RepositoryType.s3.rawValue
                    default:
                        repository = ""
                    }
                }

                Picker("Repository:", selection: repositoryType) {
                    if repositoryType.wrappedValue == .local {
                        HStack {
                            Image(nsImage: image)
                            Text(FileManager.default.displayName(atPath: repository))
                        }
                        .tag(RepositoryType.local)
                        Divider()
                    }
                    Text("SFTP")
                        .tag(RepositoryType.sftp)
                    Text("REST")
                        .tag(RepositoryType.rest)
                    Text("S3")
                        .tag(RepositoryType.s3)
                    Text("Browse…")
                        .tag(RepositoryType.browse)
                }
                .fileImporter(isPresented: $browseRepository, allowedContentTypes: [.folder], onCompletion: { result in
                    repository = try! result.get().path(percentEncoded: false)
                })
                if repositoryType.wrappedValue.hasAddress {
                    let address = Binding<String> {
                        switch true {
                        case repository.hasPrefix(RepositoryType.sftp.rawValue):
                            repository.droppingPrefix(RepositoryType.sftp.rawValue)
                        case repository.hasPrefix(RepositoryType.rest.rawValue):
                            repository.droppingPrefix(RepositoryType.rest.rawValue)
                        case repository.hasPrefix(RepositoryType.s3.rawValue):
                            repository.droppingPrefix(RepositoryType.s3.rawValue)
                        default:
                            repository
                        }
                    } set: { newValue in
                        switch repositoryType.wrappedValue {
                        case .sftp:
                            repository = RepositoryType.sftp.rawValue + newValue
                        case .rest:
                            repository = RepositoryType.rest.rawValue + newValue
                        case .s3:
                            repository = RepositoryType.s3.rawValue + newValue
                        default:
                            repository = newValue
                        }
                    }

                    TextField("Address:", text: address)
                    if repositoryType.wrappedValue == .s3 {
                        TextField("Access Key ID:", text: .optional($s3AccessKeyId))
                        SecureField("Secret Access Key:", text: .optional($s3SecretAccessKey))
                    }
                    if repositoryType.wrappedValue == .rest {
                        TextField("REST username:", text: .optional($restUsername))
                        SecureField("REST password:", text: .optional($restPassword))
                    }
                    Spacer(minLength: 18)
                }
                SecureField("Password:", text: $password)
                EditableList("Included files:", values: $includes)
                EditableList("Excluded files:", values: $excludes)
            }
            .animation(.default, value: repository)
            .frame(width: 400, alignment: .center)
            .padding()
        }
        .onChange(of: repository) { _ in
            lastSuccessfulBackupDate = nil
            resticScheduler.rescheduleStaleBackupCheck()
        }
        .onChange(of: [
            password,
            includes,
            excludes,
            s3AccessKeyId,
            s3SecretAccessKey,
            restUsername,
            restPassword,
        ] as [AnyHashable]) { _ in
            resticScheduler.rescheduleStaleBackupCheck()
        }
    }
}

#Preview {
    ResticSettingsView()
}
