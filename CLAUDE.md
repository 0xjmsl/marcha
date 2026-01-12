# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Marcha is a Windows 11 startup management tool built with Flutter and native C++. It manages VS Code windows across virtual desktops and executes startup commands.

## Technology Stack
- **Frontend**: Flutter (Dart)
- **Native Integration**: C++ with Windows APIs
- **FFI**: Dart Foreign Function Interface
- **Platform**: Windows 11

## Development Setup

### Prerequisites
- Flutter SDK
- Visual Studio with C++ build tools
- CMake
- Windows 11 SDK

### Common Commands
- Build Flutter app: `flutter build windows`
- Run in debug: `flutter run -d windows`
- Build native library: `cmake --build build --config Release`
- Get dependencies: `flutter pub get`
- Test: `flutter test`

### Git Workflow
- Main branch: `main`
- Current status: Initial Flutter + C++ integration setup

## Architecture Notes

### Project Structure
```
marcha/
├── lib/
│   ├── main.dart                    # Flutter entry point
│   └── services/                    # Dart service layer
│       ├── native_bindings.dart     # FFI bindings
│       ├── startup_service.dart     # Startup management
│       ├── process_service.dart     # Process/VS Code management
│       └── virtual_desktop_service.dart # Virtual desktop control
├── native/windows/                  # Native C++ code
│   ├── CMakeLists.txt              # Build configuration
│   ├── startup_manager.cpp/.h      # Windows startup registry
│   ├── process_manager.cpp/.h      # Process spawning
│   └── virtual_desktop_manager.cpp/.h # Virtual desktop APIs
└── windows/                        # Flutter Windows platform
```

### Key Features
1. **Startup Management**: Add/remove from Windows startup registry
2. **VS Code Automation**: Open multiple instances in different directories
3. **Virtual Desktop Control**: Switch and create virtual desktops
4. **Command Execution**: Run commands in specific working directories

## Development Guidelines
- Use FFI for all native Windows API calls
- Implement error handling in both C++ and Dart layers
- Follow Flutter/Dart naming conventions
- Keep native code minimal and focused
- Test on Windows 11 only (primary target)