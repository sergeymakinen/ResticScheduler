import SwiftUI

struct AdvancedSettingsView: View {
  @StateObject private var advancedSettings = AdvancedSettings()

  var body: some View {
    VStack {
      Form {
        Section {
          Picker("Restic:", selection: $advancedSettings.binaryType) {
            if let binary = advancedSettings.binary, !binary.isEmpty {
              HStack {
                Image(nsImage: {
                  let image = NSWorkspace.shared.icon(forFile: binary)
                  image.size = NSSize(width: 16, height: 16)
                  return image
                }())
                Text(FileManager.default.displayName(atPath: binary))
              }
              .tag(AdvancedSettings.BinaryType.manual)
              Divider()
            }
            Text("Built-in")
              .tag(AdvancedSettings.BinaryType.builtIn)
            Text("Other…")
              .tag(AdvancedSettings.BinaryType.browse)
          }
          .padding(.bottom, advancedSettings.binaryVersion.value == "" ? 10 : 0)
          .fileImporter(isPresented: $advancedSettings.browseBinary, allowedContentTypes: [.unixExecutable], onCompletion: { result in
            advancedSettings.binary = try! result.get().path(percentEncoded: false)
            advancedSettings.binaryType = .manual
          })
        } footer: {
          HStack(alignment: .top, spacing: 5) {
            if advancedSettings.binaryVersion.value != "" {
              if advancedSettings.binaryVersion.isError {
                Image(systemName: "xmark.circle.fill")
              }
              Text(advancedSettings.binaryVersion.value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .help(advancedSettings.binaryVersion.value)
                .textSelection(.enabled)
              Spacer()
            }
          }
        }
        HStack {
          Picker("Hostname:", selection: $advancedSettings.hostType) {
            Text("System")
              .tag(AdvancedSettings.HostType.system)
            Text("Custom")
              .tag(AdvancedSettings.HostType.custom)
          }
          TextField("Name:", text: $advancedSettings.host)
            .labelsHidden()
            .disabled(advancedSettings.hostType == .system)
        }
        LabeledContent("Arguments:") {
          EditableListView($advancedSettings.arguments, isBrowseable: false)
            .offset(x: 0, y: -12)
        }
      }
      .frame(width: 400, alignment: .center)
      .padding()
    }
  }
}

struct AdvancedSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    AdvancedSettingsView()
  }
}
