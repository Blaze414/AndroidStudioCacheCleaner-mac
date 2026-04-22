# Android Studio Cache Cleaner

A native macOS app for Android and Flutter developers to clean development caches and free up disk space. Built with SwiftUI.

<img width="1200" alt="App Screenshot" src="https://github.com/user-attachments/assets/7bfcb81f-e7db-4466-830e-e2ce871007a5">

## Features

### Global Cache Cleaner
Clean shared caches used across all your projects:
- **Android Studio Caches** - `~/Library/Caches/Google/AndroidStudio...`
- **Android Studio Support** - `~/Library/Application Support/Google/AndroidStudio...`
- **Gradle Caches** - `~/.gradle/caches`
- **Flutter Pub Cache** - `~/.pub-cache`

### Project Cleaner
Scan and clean individual projects:
- Detects **Flutter projects** (via `pubspec.yaml`)
- Detects **Kotlin/Gradle projects** (via `build.gradle` / `settings.gradle`)
- **Flutter Clean** - Runs `flutter clean` for Flutter projects
- **Clean Kotlin Cache** - Removes `build/` directories recursively
- **Clean All** - Combines both operations with confirmation

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Flutter SDK (for Flutter project detection)
- Zsh shell with proper PATH configuration

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/AndroidDevCacheCleaner.git
   cd AndroidDevCacheCleaner
   ```

2. Open in Xcode:
   ```bash
   open AndroidDevCacheCleaner.xcodeproj
   ```

3. Build and run (Cmd+R)

## Usage

### Global Cache Cleaner
1. Launch the app
2. Click **Refresh Sizes** to calculate cache sizes
3. Toggle items you want to clean
4. Click **Clean Selected**

### Project Cleaner
1. Click **Choose Directory** to select a folder containing projects
2. The app scans for Flutter/Kotlin projects
3. Select a project to see available cleaning options
4. Click **Flutter Clean**, **Clean Kotlin Cache**, or **Clean All**

## Building for Distribution

### With Developer Account (Recommended)
1. Set your team in project signing settings
2. Product → Archive
3. Distribute via Xcode (with notarization)

### Without Paid Account
1. Set team to "Personal Team"
2. Build for local signing
3. To run the app, right-click and select "Open" to bypass Gatekeeper

## Troubleshooting

**Flutter not found?**
- Ensure Flutter is in your PATH (add to `~/.zshrc` or `~/.zprofile`)
- Test with: `zsh -ilc "which flutter"`

**Can't click sidebar items?**
- Update to the latest version of the app
- Report issues on GitHub

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or pull request on GitHub.
