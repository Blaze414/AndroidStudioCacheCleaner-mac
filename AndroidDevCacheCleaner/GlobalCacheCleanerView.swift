import SwiftUI

// MARK: - Helper Functions

func findDirectory(in basePath: String, withPrefix prefix: String) -> String? {
    let fm = FileManager.default
    let baseURL = URL(fileURLWithPath: basePath)
    do {
        let contents = try fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
        let filtered = contents.filter { $0.lastPathComponent.hasPrefix(prefix) }
        guard !filtered.isEmpty else { return nil }
        return filtered.sorted { $0.lastPathComponent > $1.lastPathComponent }.first?.path
    } catch { return nil }
}

func findAndroidStudioCachePath() -> String {
    let base = NSHomeDirectory() + "/Library/Caches/Google"
    return findDirectory(in: base, withPrefix: "AndroidStudio")
        ?? NSHomeDirectory() + "/Library/Caches/AndroidStudio"
}

func findAndroidStudioSupportPath() -> String {
    let base = NSHomeDirectory() + "/Library/Application Support/Google"
    return findDirectory(in: base, withPrefix: "AndroidStudio")
        ?? NSHomeDirectory() + "/Library/Application Support/Google/AndroidStudio"
}

// MARK: - Model

struct CacheItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    var isSelected: Bool = true
    var size: UInt64? = nil

    // Convenience
    var sizeLabel: String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var pathExists: Bool { FileManager.default.fileExists(atPath: path) }
}

// MARK: - ViewModel

@MainActor
class CacheCleanerViewModel: ObservableObject {
    @Published var cacheItems: [CacheItem]
    @Published var logLines: [LogLine] = []
    @Published var isCleaning  = false
    @Published var isCalculating = false

    struct LogLine: Identifiable {
        let id = UUID()
        let kind: Kind
        let text: String
        enum Kind { case info, success, error }
    }

    init() {
        cacheItems = [
            CacheItem(name: "Android Studio Caches",  path: findAndroidStudioCachePath(),  icon: "androidstudio"),
            CacheItem(name: "Android Studio Support", path: findAndroidStudioSupportPath(), icon: "gearshape.2"),
            CacheItem(name: "Gradle Caches",          path: NSHomeDirectory() + "/.gradle/caches", icon: "wrench.and.screwdriver"),
            CacheItem(name: "Flutter Pub Cache",      path: NSHomeDirectory() + "/.pub-cache",     icon: "shippingbox"),
        ]
    }

    // ── Size Calculation ──────────────────────────────────────────────────

    func calculateSizes() async {
        isCalculating = true
        defer { isCalculating = false }
        for index in cacheItems.indices {
            let path = cacheItems[index].path
            let url  = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                cacheItems[index].size = await directorySize(url: url)
            } else {
                cacheItems[index].size = 0
            }
        }
    }

    private nonisolated func directorySize(url: URL) async -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [],
            errorHandler: nil
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let rv = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  rv.isRegularFile == true,
                  let size = rv.fileSize else { continue }
            total += UInt64(size)
        }
        return total
    }

    // ── Cleaning ──────────────────────────────────────────────────────────

    func cleanSelected() async {
        isCleaning = true
        defer { isCleaning = false }
        logLines.removeAll()

        for item in cacheItems where item.isSelected {
            let url = URL(fileURLWithPath: item.path)
            if FileManager.default.fileExists(atPath: item.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    logLines.append(.init(kind: .success, text: "Deleted \(item.name)"))
                } catch {
                    logLines.append(.init(kind: .error, text: "Failed to delete \(item.name): \(error.localizedDescription)"))
                }
            } else {
                logLines.append(.init(kind: .info, text: "Not found: \(item.name) (\(item.path))"))
            }
        }
    }

    var selectedCount: Int { cacheItems.filter(\.isSelected).count }
}

// MARK: - GlobalCacheCleanerView

struct GlobalCacheCleanerView: View {
    @StateObject private var vm = CacheCleanerViewModel()
    @State private var showConfirmation = false
    @State private var tableSelection: Set<CacheItem.ID> = []

    var body: some View {
        VStack(spacing: 0) {

            // ── Detail Header ─────────────────────────────────────────────
            header

            Divider()

            // ── Cache Table ───────────────────────────────────────────────
            Table(vm.cacheItems, selection: $tableSelection) {
                TableColumn("") { item in
                    Toggle("", isOn: selectionBinding(for: item.id))
                        .labelsHidden()
                }
                .width(24)

                TableColumn("Cache") { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).fontWeight(.medium)
                            Text(item.path)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.vertical, 2)
                }

                TableColumn("Status") { item in
                    if item.pathExists {
                        Label("Present", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Label("Not Found", systemImage: "minus.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .width(90)

                TableColumn("Size") { item in
                    if vm.isCalculating && item.size == nil {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(item.sizeLabel)
                            .monospacedDigit()
                            .foregroundStyle(item.size == 0 ? .tertiary : .primary)
                    }
                }
                .width(90)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 180)

            Divider()

            // ── Toolbar Strip ─────────────────────────────────────────────
            HStack(spacing: 12) {
                Button {
                    Task { await vm.calculateSizes() }
                } label: {
                    Label(vm.isCalculating ? "Calculating…" : "Calculate Sizes",
                          systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90.circle")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isCalculating)
                .controlSize(.large)

                Spacer()

                if vm.selectedCount > 0 {
                    Text("\(vm.selectedCount) selected")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label("Clean Selected", systemImage: "trash")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(vm.isCleaning || vm.selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            // ── Warning Banner ────────────────────────────────────────────
            if vm.selectedCount > 0 {
                warningBanner
            }

            // ── Activity Log ──────────────────────────────────────────────
            if !vm.logLines.isEmpty {
                Divider()
                logView
            }
        }
        .navigationTitle("Global Caches")
        .navigationSubtitle("Shared caches for Gradle, Flutter & Android Studio")
        .toolbar { toolbarContent }
        .alert("Clean \(vm.selectedCount) Cache(s)?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                Task { await vm.cleanSelected() }
            }
        } message: {
            Text("The next build will be slower as caches are rebuilt from scratch. This action cannot be undone.")
        }
    }

    // ── Subviews ──────────────────────────────────────────────────────────

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "internaldrive.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Global Cache Cleaner")
                    .font(.title2.weight(.semibold))
                Text("Frees space used by tools shared across all your Android & Flutter projects.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Cleaning will slow your next build — all caches must be re-downloaded or rebuilt.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 8)               // glass on macOS Tahoe, material fallback below
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(vm.logLines) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: logIcon(line.kind))
                                .foregroundStyle(logColor(line.kind))
                                .font(.caption)
                                .frame(width: 14)
                            Text(line.text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(logColor(line.kind))
                                .textSelection(.enabled)
                        }
                        .id(line.id)
                    }
                }
                .padding(12)
                .onChange(of: vm.logLines.count) { _ in
                    proxy.scrollTo(vm.logLines.last?.id)
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .frame(height: 130)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await vm.calculateSizes() }
            } label: {
                Label("Refresh Sizes", systemImage: "arrow.clockwise")
            }
            .disabled(vm.isCalculating)
            .help("Recalculate cache sizes on disk")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private func selectionBinding(for id: CacheItem.ID) -> Binding<Bool> {
        Binding(
            get: { vm.cacheItems.first(where: { $0.id == id })?.isSelected ?? false },
            set: { newVal in
                if let idx = vm.cacheItems.firstIndex(where: { $0.id == id }) {
                    vm.cacheItems[idx].isSelected = newVal
                }
            }
        )
    }

    private func logIcon(_ kind: CacheCleanerViewModel.LogLine.Kind) -> String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle"
        }
    }

    private func logColor(_ kind: CacheCleanerViewModel.LogLine.Kind) -> Color {
        switch kind {
        case .success: return .green
        case .error:   return .red
        case .info:    return .secondary
        }
    }
}

#Preview { GlobalCacheCleanerView().environmentObject(AppSettings()) }
