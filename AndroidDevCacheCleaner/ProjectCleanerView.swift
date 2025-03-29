import SwiftUI
import AppKit

// MARK: - Model for a Discovered Project

struct ProjectItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isFlutterProject: Bool
    let isKotlinProject: Bool
}

// MARK: - ViewModel for Project Cleaning

class ProjectCleanerViewModel: ObservableObject {
    @Published var projectSourceDirectory: URL?
    @Published var projectItems: [ProjectItem] = []
    @Published var logText = ""
    @Published var isScanning = false
    @Published var isCleaning = false
    
    /// Uses zsh with login and interactive flags to dynamically retrieve the Flutter executable path.
    func findFlutterPath() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Use -i (interactive) and -l (login) so that ~/.zshrc and ~/.zprofile are sourced.
        process.arguments = ["-ilc", "which flutter"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            // Debug: print the raw output.
            print("Raw output from which flutter: [\(output)]")
            // Split the output into lines and filter out any that contain "Permission denied"
            let lines = output.components(separatedBy: "\n")
                .filter { !$0.contains("Permission denied") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            // Use the last valid line (if any) as the Flutter path.
            if let flutterPath = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let resolvedPath = URL(fileURLWithPath: flutterPath).resolvingSymlinksInPath().path
                print("Resolved Flutter path: [\(resolvedPath)]")
                if !FileManager.default.fileExists(atPath: resolvedPath) {
                    print("File does not exist at \(resolvedPath)")
                }
                return resolvedPath
            }
            return nil
        } catch {
            print("Error finding flutter: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Opens an NSOpenPanel so the user can choose a directory that contains project(s).
    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Project Source Directory"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            DispatchQueue.main.async {
                self.projectSourceDirectory = url
            }
            Task { await scanProjects(directory: url) }
        }
    }
    
    /// Checks if the given directory is a Flutter or Kotlin project by looking for key files.
    private func checkIfDirectoryIsProject(_ dirURL: URL) -> (isFlutter: Bool, isKotlin: Bool) {
        let fileManager = FileManager.default
        let flutterFile = dirURL.appendingPathComponent("pubspec.yaml").path
        let gradleFile = dirURL.appendingPathComponent("build.gradle").path
        let settingsFile = dirURL.appendingPathComponent("settings.gradle").path
        
        let isFlutter = fileManager.fileExists(atPath: flutterFile)
        let isKotlin = fileManager.fileExists(atPath: gradleFile) || fileManager.fileExists(atPath: settingsFile)
        return (isFlutter, isKotlin)
    }
    
    /// Scans the chosen directory to detect projects (both at the top level and in subdirectories).
    func scanProjects(directory: URL) async {
        await MainActor.run {
            self.isScanning = true
            self.projectItems = []
        }
        let fileManager = FileManager.default
        
        // 1. Check if the chosen directory itself is a project.
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue {
            let (isFlutter, isKotlin) = checkIfDirectoryIsProject(directory)
            if isFlutter || isKotlin {
                let project = ProjectItem(name: directory.lastPathComponent,
                                          path: directory.path,
                                          isFlutterProject: isFlutter,
                                          isKotlinProject: isKotlin)
                await MainActor.run { self.projectItems.append(project) }
            }
        }
        
        // 2. Scan immediate subdirectories.
        do {
            let contents = try fileManager.contentsOfDirectory(at: directory,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles])
            for item in contents {
                var isSubDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isSubDir), isSubDir.boolValue {
                    let (isFlutter, isKotlin) = checkIfDirectoryIsProject(item)
                    if isFlutter || isKotlin {
                        let project = ProjectItem(name: item.lastPathComponent,
                                                  path: item.path,
                                                  isFlutterProject: isFlutter,
                                                  isKotlinProject: isKotlin)
                        await MainActor.run { self.projectItems.append(project) }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.logText += "Error scanning directory: \(error.localizedDescription)\n"
            }
        }
        await MainActor.run {
            self.isScanning = false
            self.logText += "Found \(self.projectItems.count) project(s) in \(directory.path)\n"
        }
    }
    
    /// Runs "flutter clean" for a Flutter project using the dynamically determined Flutter path.
    func flutterClean(project: ProjectItem) async -> String {
        guard let flutterPath = await findFlutterPath() else {
            return "Error: Flutter executable not found in PATH."
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: flutterPath)
        process.arguments = ["clean"]
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return "Flutter clean output for \(project.name):\n" + output
        } catch {
            return "Error running flutter clean on \(project.name): \(error.localizedDescription)\n"
        }
    }
    
    /// Recursively deletes "build" directories for a Kotlin project.
    func cleanKotlinCache(project: ProjectItem) async -> String {
        let fileManager = FileManager.default
        let projectURL = URL(fileURLWithPath: project.path)
        var log = ""
        if let enumerator = fileManager.enumerator(at: projectURL, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "build" {
                    do {
                        try fileManager.removeItem(at: url)
                        log += "Deleted build folder: \(url.path)\n"
                    } catch {
                        log += "Failed to delete build folder at \(url.path): \(error.localizedDescription)\n"
                    }
                }
            }
        }
        return "Kotlin cache cleanup for \(project.name):\n" + log
    }
    
    /// Cleans both Flutter and Kotlin caches for the given project.
    func cleanProject(project: ProjectItem) async {
        self.isCleaning = true
        var log = ""
        if project.isFlutterProject {
            log += await flutterClean(project: project)
        }
        if project.isKotlinProject {
            log += await cleanKotlinCache(project: project)
        }
        await MainActor.run {
            self.logText += log + "\n"
            self.isCleaning = false
        }
    }
}

// MARK: - ProjectCleanerView

struct ProjectCleanerView: View {
    @StateObject private var viewModel = ProjectCleanerViewModel()
    @State private var selectedProjectForCleaning: ProjectItem?
    @State private var showProjectWarning = false

    var body: some View {
        VStack {
            // Directory chooser.
            HStack {
                if let dir = viewModel.projectSourceDirectory {
                    Text("Directory: \(dir.path)")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No directory selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Choose Directory") {
                    viewModel.chooseDirectory()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            if viewModel.isScanning {
                ProgressView("Scanning projects...")
                    .padding()
            }

            // List of discovered projects.
            List {
                ForEach(viewModel.projectItems) { project in
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            // Dedicated Flutter Clean button.
                            if project.isFlutterProject {
                                Button("Flutter Clean") {
                                    Task {
                                        let output = await viewModel.flutterClean(project: project)
                                        await MainActor.run {
                                            viewModel.logText += output + "\n"
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            // Dedicated Kotlin cache cleaning button.
                            if project.isKotlinProject {
                                Button("Clean Kotlin Cache") {
                                    Task {
                                        let output = await viewModel.cleanKotlinCache(project: project)
                                        await MainActor.run {
                                            viewModel.logText += output + "\n"
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            // "Clean All" button runs both operations.
                            if project.isFlutterProject || project.isKotlinProject {
                                Button("Clean All") {
                                    selectedProjectForCleaning = project
                                    showProjectWarning = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            Text("Warning: Cleaning project caches will slow down your next build as caches need to be rebuilt.")
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
            .frame(height: 200)
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Warning", isPresented: $showProjectWarning, presenting: selectedProjectForCleaning) { project in
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                Task { await viewModel.cleanProject(project: project) }
            }
        } message: { project in
            Text("Cleaning caches for \(project.name) will result in slower subsequent builds because necessary files will have to be re-downloaded or rebuilt. Do you wish to continue?")
        }
    }
}

struct ProjectCleanerView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectCleanerView()
    }
}
