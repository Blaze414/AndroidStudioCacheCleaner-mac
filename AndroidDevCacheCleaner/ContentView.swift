import SwiftUI

// MARK: - Navigation Destination

enum AppDestination: String, CaseIterable, Identifiable {
    case globalCaches   = "Global Caches"
    case projectCleaner = "Project Cleaner"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .globalCaches:   return "internaldrive.fill"
        case .projectCleaner: return "folder.badge.gearshape"
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: AppDestination? = .globalCaches

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            // ── Sidebar ──────────────────────────────────────────────────
            List(selection: $selection) {
                NavigationLink(value: AppDestination.globalCaches) {
                    Label("Global Caches", systemImage: "internaldrive.fill")
                }
                
                NavigationLink(value: AppDestination.projectCleaner) {
                    Label("Project Cleaner", systemImage: "folder.badge.gearshape")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Dev Cache Cleaner")

        } detail: {

            // ── Detail ───────────────────────────────────────────────────
            switch selection {
            case .globalCaches:
                GlobalCacheCleanerView()
            case .projectCleaner:
                ProjectCleanerView()
            case nil:
                WelcomeView()
            }
        }
        .frame(minWidth: 860, minHeight: 580)
    }
}

// MARK: - Welcome / Empty State

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Select a Tool")
                .font(.title2.weight(.semibold))
            Text("Choose Global Caches or Project Cleaner from the sidebar.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
