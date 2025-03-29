# AndroidDevCacheCleaner

AndroidDevCacheCleaner is a macOS application designed for developers using Android Studio, Flutter, and Kotlin projects. It helps you clear out various caches that can slow down your builds. The app automatically detects and cleans global caches (such as Android Studio caches, Gradle caches, and Flutter Pub Cache) and also scans a user-selected directory to locate individual Flutter/Kotlin projects so you can run project-specific cleaning (e.g., `flutter clean`).

> **Warning:** Cleaning caches may slow down your next build since files and packages will be re-downloaded or recompiled.

---

## Features

- **Global Cache Cleaning**
  - Detects and cleans Android Studio caches and support files (located in `~/Library/Caches/Google/AndroidStudio...` and `~/Library/Application Support/Google/AndroidStudio...`).
  - Clears Gradle caches (usually at `~/.gradle/caches`).
  - Offers an option to clear the Flutter Pub Cache (`~/.pub-cache`).

- **Project Cleaner**
  - Scans a chosen directory for projects by checking for key files such as `pubspec.yaml` (for Flutter projects) and Gradle files (for Kotlin projects).
  - Provides dedicated buttons to run:
    - **Flutter Clean:** Executes `flutter clean` using a dynamically determined Flutter executable.
    - **Clean Kotlin Cache:** Recursively removes build directories for Kotlin projects.
    - **Clean All:** Runs both cleaning operations with a user confirmation warning.

- **Dynamic Flutter Path Detection**
  - Uses a zsh command (`zsh -ilc "which flutter"`) to dynamically locate the Flutter executable without hardcoding the path.
  - Filters out any warnings (like permission messages) that might be prepended to the output.

- **Packaging Without a Paid Developer Subscription**
  - You can build and package the app with Xcode using a free provisioning profile.
  - Note that without notarization (which requires a paid Apple Developer account), users may encounter a Gatekeeper warning. They can bypass it by right‑clicking the app and choosing “Open.”

---

## Prerequisites

- **macOS** with Xcode 16.2 or later.
- **Flutter SDK** must be installed and accessible (ensure your shell configuration exports Flutter's bin directory).
- **Zsh** as your default shell with proper PATH settings in `~/.zprofile` and/or `~/.zshrc`.

---

## Installation and Usage

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/AndroidDevCacheCleaner.git
   cd AndroidDevCacheCleaner
   ```

2. **Open the Project in Xcode:**

   Open `AndroidDevCacheCleaner.xcodeproj` in Xcode.

3. **Build and Run the App:**

   - Use the **Global Cache Cleaner** tab to calculate cache sizes and clean common caches.
   - Use the **Project Cleaner** tab to choose a directory, scan for projects, and run project-specific cleaning commands.

4. **Packaging:**

   - Archive the app via **Product → Archive**.
   - Export the app using your free provisioning profile. Note that the app won’t be notarized, so users will need to bypass Gatekeeper warnings by right‑clicking the app and selecting “Open.”

---

## Troubleshooting

- **Flutter Executable Not Found:**
  - Verify in Terminal with:
    ```bash
    zsh -ilc "which flutter"
    ```
  - Ensure the Flutter bin directory is in your PATH by checking your `~/.zprofile` or `~/.zshrc`.
  - If you see permission warnings (like for `composer.save`), adjust the file permissions accordingly.

- **Sandboxing Issues:**
  - If launching external executables fails due to sandbox restrictions, consider temporarily disabling sandboxing for testing or configuring the appropriate entitlements.

- **Debugging Flutter Path:**
  - The app logs the raw output from `which flutter` and the resolved path. Check the debug console in Xcode for details.

---

## Contributing

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request on GitHub.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgements

Thanks to the developer community for sharing insights on cache management, macOS sandboxing, and environment variable configuration that made this project possible.

---
