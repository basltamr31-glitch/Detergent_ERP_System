# Detergent Factory Management App

A Flutter application for detergent factory owners with Arabic RTL support. Runs on **Android**, **Windows**, **Linux**, and **macOS**.

## Features

- Production Management
- Multi-step form workflow
- Dynamic tables with add/remove functionality
- Automatic calculations
- Offline-first architecture
- PDF export capability
- Multi-platform support (Android, Windows, Linux, macOS)

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- For Android: Android Studio with Android SDK
- For Windows: Visual Studio with C++ development tools
- For Linux: CMake, GTK development libraries, pkg-config
- For macOS: Xcode

## Getting Started

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Check available devices:
```bash
flutter devices
```

## Running on Different Platforms

### Android
```bash
# Connect an Android device or start an emulator
flutter run
# Or specify Android explicitly
flutter run -d android
```

### Windows
```bash
flutter run -d windows
```

### Linux
```bash
flutter run -d linux
```

### macOS
```bash
flutter run -d macos
```

## Building for Release

### Android APK
```bash
flutter build apk --release
# Or for app bundle
flutter build appbundle --release
```

### Windows
```bash
flutter build windows --release
```

### Linux
```bash
flutter build linux --release
```

### macOS
```bash
flutter build macos --release
```

## Project Structure

- `lib/models/` - Data models
- `lib/providers/` - State management (Provider)
- `lib/screens/` - UI screens
- `lib/widgets/` - Reusable widgets
- `android/` - Android platform-specific code
- `windows/` - Windows platform-specific code
- `linux/` - Linux platform-specific code
- `macos/` - macOS platform-specific code

## Platform-Specific Notes

- **Android**: Minimum SDK version is set automatically by Flutter
- **Windows**: Requires Windows 10 or later
- **Linux**: Requires GTK 3.0 or later
- **macOS**: Requires macOS 10.11 or later

