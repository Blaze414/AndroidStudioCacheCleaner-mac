import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GlobalCacheCleanerView()
                .tabItem {
                    Label("Global Caches", systemImage: "trash")
                }
            ProjectCleanerView()
                .tabItem {
                    Label("Project Cleaner", systemImage: "folder")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
