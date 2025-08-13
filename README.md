# Focus

A macOS menu bar application that provides a web browser interface accessible from the system menu bar. Focus runs as an accessory app, allowing you to quickly browse websites without opening a full browser window.

## Features

- **Menu Bar Integration**: Appears in the macOS menu bar with a play icon
- **Embedded Web Browser**: Full WebKit-powered web browsing capability
- **Compact Interface**: Minimal UI optimized for quick access
- **URL Navigation**: Enter any URL and navigate to websites
- **Refresh & Quit Controls**: Simple toolbar for basic browser functions

## Requirements

- macOS (built with SwiftUI and AppKit)
- Xcode for building from source

## Building

### Debug Build
```bash
xcodebuild -project Focus.xcodeproj -scheme Focus -configuration Debug
```

### Release Distribution
```bash
xcodebuild -project Focus.xcodeproj -scheme Focus -configuration Release -derivedDataPath build clean build
```

The built application will be located at:
```
build/Build/Products/Release/Focus.app
```

## Usage

1. Launch Focus.app
2. The application will appear in your menu bar as a play button icon
3. Click the icon to open the web browser interface
4. Enter a URL in the text field and press Enter or click "Go"
5. Use the Refresh button to reload the current page
6. Use the Quit button to exit the application

## Architecture

- **FocusApp.swift**: Main app entry point with menu bar configuration
- **ContentView.swift**: SwiftUI interface with embedded WebKit view
- **WebView**: Custom NSViewRepresentable wrapper for WKWebView

The app runs as an `.accessory` application, meaning it doesn't appear in the Dock and focuses on menu bar functionality.
