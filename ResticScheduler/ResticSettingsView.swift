import SwiftUI

struct ResticSettingsView: View {
  @StateObject private var resticSettings = ResticSettings()

  var body: some View {
    VStack {
      Form {
        Picker("Repository:", selection: $resticSettings.repositoryType) {
          if resticSettings.repositoryType == .local {
            HStack {
              Image(nsImage: {
                let image = NSWorkspace.shared.icon(forFile: resticSettings.repository)
                image.size = NSSize(width: 16, height: 16)
                return image
              }())
              Text(FileManager.default.displayName(atPath: resticSettings.repository))
            }
            .tag(ResticSettings.RepositoryType.local)
            Divider()
          }
          Text("SFTP")
            .tag(ResticSettings.RepositoryType.sftp)
          Text("Rest")
            .tag(ResticSettings.RepositoryType.rest)
          Text("S3")
            .tag(ResticSettings.RepositoryType.s3)
          Text("Browse…")
            .tag(ResticSettings.RepositoryType.browse)
        }
        .fileImporter(isPresented: $resticSettings.browseRepository, allowedContentTypes: [.folder], onCompletion: { result in
          resticSettings.repositoryType = .local
          resticSettings.repository = try! result.get().path(percentEncoded: false)
        })
        if resticSettings.repositoryType.hasAddress {
          TextField("Address:", text: $resticSettings.repository)
            .padding(.bottom, 10)
        }
        if resticSettings.repositoryType == .s3 {
            TextField("Access Key ID:", text: $resticSettings.s3AccessKeyId)
            SecureField("Secret Access Key:", text: $resticSettings.s3SecretAccessKey)
        }
        SecureField("Password:", text: $resticSettings.password)
        LabeledContent("Included files:") {
          EditableListView($resticSettings.includes)
            .offset(x: 0, y: -12)
        }
        LabeledContent("Excluded files:") {
          EditableListView($resticSettings.excludes)
            .offset(x: 0, y: -12)
        }
      }
      .animation(.default, value: resticSettings.repositoryType)
      .frame(width: 400, alignment: .center)
      .padding()
    }
  }
}

struct ResticSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ResticSettingsView()
  }
}
