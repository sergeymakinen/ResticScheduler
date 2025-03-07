import SwiftUI

struct SettingsView: View {
    private enum Tab: Int, Hashable {
        case general, restic, advanced
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)
            ResticSettingsView()
                .tabItem {
                    Label("Restic", systemImage: "umbrella")
                }
                .tag(Tab.restic)
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(Tab.advanced)
        }
        .padding(.horizontal, 40)
        .fixedSize()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
