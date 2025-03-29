import SwiftUI

// MARK: - Helper Functions

/// Searches a given base path for a directory whose name begins with the specified prefix.
/// Returns the full path of the first matching directory (sorted in descending order) or nil if none is found.
func findDirectory(in basePath: String, withPrefix prefix: String) -> String? {
    let fm = FileManager.default
    let baseURL = URL(fileURLWithPath: basePath)
    do {
        let contents = try fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
        let filtered = contents.filter { $0.lastPathComponent.hasPrefix(prefix) }
        if filtered.isEmpty { return nil }
        // Sort descending to pick the highest version (assuming later versions sort higher lexicographically).
        let sorted = filtered.sorted { $0.lastPathComponent > $1.lastPathComponent }
        return sorted.first?.path
    } catch {
        return nil
    }
}

/// Returns the dynamically found Android Studio cache directory, or a fallback if none is found.
func findAndroidStudioCachePath() -> String {
    let googleCachesPath = NSHomeDirectory() + "/Library/Caches/Google"
    if let foundPath = findDirectory(in: googleCachesPath, withPrefix: "AndroidStudio") {
        return foundPath
    }
    // Fallback path if none found.
    return NSHomeDirectory() + "/Library/Caches/AndroidStudio"
}

/// Returns the dynamically found Android Studio support directory, or a fallback if none is found.
func findAndroidStudioSupportPath() -> String {
    let googleSupportPath = NSHomeDirectory() + "/Library/Application Support/Google"
    if let foundPath = findDirectory(in: googleSupportPath, withPrefix: "AndroidStudio") {
        return foundPath
    }
    // Fallback path.
    return NSHomeDirectory() + "/Library/Application Support/Google/AndroidStudio"
}

// MARK: - Model for a Cache Item

struct CacheItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var isSelected: Bool = true
    var size: UInt64? = nil
}

// MARK: - ViewModel for Global Cache Cleaning

class CacheCleanerViewModel: ObservableObject {
    @Published var cacheItems: [CacheItem]
    @Published var logText = ""
    @Published var isCleaning = false
    @Published var isCalculating = false

    init() {
        // Dynamically retrieve paths for Android Studio caches and support directories.
        let androidStudioCache = findAndroidStudioCachePath()
        let androidStudioSupport = findAndroidStudioSupportPath()
        let gradleCache = NSHomeDirectory() + "/.gradle/caches"
        // Flutter Pub Cache is typically located in the user's home directory.
        let flutterPubCache = NSHomeDirectory() + "/.pub-cache"
        
        self.cacheItems = [
            CacheItem(name: "Android Studio Caches", path: androidStudioCache),
            CacheItem(name: "Android Studio Support", path: androidStudioSupport),
            CacheItem(name: "Gradle Caches", path: gradleCache),
            CacheItem(name: "Flutter Pub Cache", path: flutterPubCache)
        ]
    }
    
    // Asynchronously calculate the size of each cache directory.
    func calculateSizes() async {
        isCalculating = true
        defer { isCalculating = false }
        
        for index in cacheItems.indices {
            let path = cacheItems[index].path
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                if let size = await directorySize(url: url) {
                    await MainActor.run { self.cacheItems[index].size = size }
                } else {
                    await MainActor.run { self.cacheItems[index].size = nil }
                }
            } else {
                await MainActor.run { self.cacheItems[index].size = 0 }
            }
        }
    }
    
    // Recursively compute the size of a directory.
    func directorySize(url: URL) async -> UInt64? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url,
                                                        includingPropertiesForKeys: [.fileSizeKey],
                                                        options: [],
                                                        errorHandler: nil) else {
            return nil
        }
        var totalSize: UInt64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true, let fileSize = resourceValues.fileSize {
                    totalSize += UInt64(fileSize)
                }
            } catch {
                continue
            }
        }
        return totalSize
    }
    
    // Remove selected cache directories.
    func cleanSelected() async {
        isCleaning = true
        defer { isCleaning = false }
        var log = ""
        for item in cacheItems where item.isSelected {
            let path = item.path
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    log += "Deleted \(item.name) at:\n\(path)\n\n"
                } catch {
                    log += "Failed to delete \(item.name) at \(path): \(error.localizedDescription)\n\n"
                }
            } else {
                log += "Path not found for \(item.name): \(path)\n\n"
            }
        }
        await MainActor.run { self.logText = log }
    }
}

// MARK: - GlobalCacheCleanerView

struct GlobalCacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    @State private var showGlobalWarning = false
    
    var body: some View {
        VStack {
            // Header with a modern gradient style.
            Text("Android Studio & Flutter Cache Cleaner")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing))
                .padding(.top)
            
            List {
                ForEach($viewModel.cacheItems) { $item in
                    HStack {
                        Toggle(isOn: $item.isSelected) {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if let size = item.size {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.subheadline)
                        } else {
                            Text("Unknown")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            
            HStack {
                Button {
                    Task { await viewModel.calculateSizes() }
                } label: {
                    if viewModel.isCalculating {
                        ProgressView()
                    } else {
                        Text("Calculate Cache Sizes")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                
                // Clean button that triggers a warning alert.
                Button {
                    showGlobalWarning = true
                } label: {
                    if viewModel.isCleaning {
                        ProgressView()
                    } else {
                        Text("Clean Selected")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(viewModel.isCleaning)
            }
            .padding(.vertical)
            
            Text("Warning: Cleaning caches will slow down your next build as files and packages will need to be re-downloaded or rebuilt.")
                .foregroundColor(.red)
                .font(.caption)
                .padding(.bottom, 5)
            
            ScrollView {
                Text(viewModel.logText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.windowBackgroundColor)))
            .padding()
            .frame(height: 150)
        }
        .frame(width: 600, height: 500)
        .alert("Warning", isPresented: $showGlobalWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                Task { await viewModel.cleanSelected() }
            }
        } message: {
            Text("Cleaning caches will mean that the next time you build your project, it will take longer as caches need to be rebuilt from scratch. Do you wish to continue?")
        }
    }
}

struct GlobalCacheCleanerView_Previews: PreviewProvider {
    static var previews: some View {
        GlobalCacheCleanerView()
    }
}
