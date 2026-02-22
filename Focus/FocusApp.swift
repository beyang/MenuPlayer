//
//  FocusApp.swift
//  Focus
//
//  Created by Beyang Liu on 7/19/25.
//

import SwiftUI
import AppKit
import CoreData
import Carbon.HIToolbox

final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct SpotlightCommand: Identifiable {
    let id = UUID()
    let name: String
    let aliases: [String]
    let action: () -> Void

    var searchableTerms: [String] {
        [name] + aliases
    }
}

final class CommandRegistry {
    private var commands: [SpotlightCommand] = []

    func register(_ command: SpotlightCommand) {
        commands.append(command)
    }

    func execute(_ command: SpotlightCommand) {
        command.action()
    }

    func matchingCommands(for input: String) -> [SpotlightCommand] {
        let query = normalize(input)
        if query.isEmpty {
            return commands
        }

        return commands
            .compactMap { command -> (SpotlightCommand, Int)? in
                let bestScore = command.searchableTerms
                    .compactMap { fuzzyScore(query: query, candidate: normalize($0)) }
                    .max()

                guard let bestScore, bestScore > 0 else {
                    return nil
                }

                return (command, bestScore)
            }
            .sorted { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.name < rhs.0.name : lhs.1 > rhs.1
            }
            .map(\.0)
    }

    private func normalize(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func fuzzyScore(query: String, candidate: String) -> Int? {
        guard !query.isEmpty, !candidate.isEmpty else {
            return nil
        }

        let queryChars = Array(query)
        let candidateChars = Array(candidate)
        var queryIndex = 0
        var candidateIndex = 0
        var score = 0
        var previousMatchIndex: Int?

        while queryIndex < queryChars.count {
            let target = queryChars[queryIndex]
            var foundIndex: Int?

            while candidateIndex < candidateChars.count {
                if candidateChars[candidateIndex] == target {
                    foundIndex = candidateIndex
                    candidateIndex += 1
                    break
                }
                candidateIndex += 1
            }

            guard let matchIndex = foundIndex else {
                return nil
            }

            score += 10

            if let previousMatchIndex {
                if matchIndex == previousMatchIndex + 1 {
                    score += 7
                } else {
                    score -= (matchIndex - previousMatchIndex - 1)
                }
            }

            if matchIndex == 0 {
                score += 6
            } else {
                let previousChar = candidateChars[matchIndex - 1]
                if previousChar == " " || previousChar == "-" || previousChar == "_" {
                    score += 4
                }
            }

            previousMatchIndex = matchIndex
            queryIndex += 1
        }

        score -= max(0, candidateChars.count - queryChars.count)
        return score
    }
}

struct SpotlightPanelContentView: View {
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var commandFieldFocused: Bool

    let commandSuggestions: (String) -> [SpotlightCommand]
    let onSubmitSelection: (SpotlightCommand?) -> Void

    private var visibleCommands: [SpotlightCommand] {
        commandSuggestions(query)
    }

    private var selectedCommand: SpotlightCommand? {
        guard !visibleCommands.isEmpty else { return nil }
        let safeIndex = min(max(selectedIndex, 0), visibleCommands.count - 1)
        return visibleCommands[safeIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Type a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.08))
                    )
                    .focused($commandFieldFocused)
                    .onSubmit {
                        onSubmitSelection(selectedCommand)
                        query = ""
                        selectedIndex = 0
                    }
                    .onChange(of: query) {
                        selectedIndex = 0
                    }
                    .onKeyPress(.upArrow) {
                        guard !visibleCommands.isEmpty else { return .handled }
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        guard !visibleCommands.isEmpty else { return .handled }
                        selectedIndex = min(selectedIndex + 1, visibleCommands.count - 1)
                        return .handled
                    }

                if !visibleCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(visibleCommands.prefix(6).enumerated()), id: \.element.id) { index, command in
                            Text(command.name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(index == selectedIndex ? Color.white : Color.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index == selectedIndex ? Color.accentColor : Color.black.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onTapGesture {
                                    selectedIndex = index
                                    onSubmitSelection(command)
                                    query = ""
                                }
                        }
                    }
                }
            }
            .padding(12)

            Divider()

            ContentView()
        }
        .onAppear {
            commandFieldFocused = true
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    private var spotlightPanel: SpotlightPanel?
    private let commandRegistry = CommandRegistry()
    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.shared = self
        registerCommands()
        registerGlobalHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    func registerGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4355) // "FOCU"
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            print("[Focus] Hotkey pressed!")
            DispatchQueue.main.async {
                AppDelegate.shared?.toggleSpotlightInput()
            }
            return noErr
        }
        
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        print("[Focus] InstallEventHandler status: \(installStatus)")
        
        // Ctrl+Shift+Space: kVK_Space = 49, controlKey = 4096, shiftKey = 512
        let modifiers: UInt32 = UInt32(controlKey | shiftKey)
        let registerStatus = RegisterEventHotKey(UInt32(kVK_Space), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        print("[Focus] RegisterEventHotKey status: \(registerStatus), hotKeyRef: \(String(describing: hotKeyRef))")
    }
    
    func toggleSpotlightInput() {
        if let spotlightPanel, spotlightPanel.isVisible {
            spotlightPanel.orderOut(nil)
            return
        }

        showSpotlightInput()
    }

    func showSpotlightInput() {
        let panel = spotlightPanel ?? makeSpotlightPanel()
        spotlightPanel = panel

        positionSpotlightPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func makeSpotlightPanel() -> SpotlightPanel {
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 1000),
            styleMask: [.titled, .fullSizeContentView, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.title = "Focus"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: makeSpotlightRootView())
        return panel
    }

    private func makeSpotlightRootView() -> some View {
        SpotlightPanelContentView(
            commandSuggestions: { [commandRegistry] input in
                commandRegistry.matchingCommands(for: input)
            },
            onSubmitSelection: { [weak self] selectedCommand in
                guard let self, let selectedCommand else {
                    NSSound.beep()
                    return
                }

                self.commandRegistry.execute(selectedCommand)
                self.spotlightPanel?.orderOut(nil)
            }
        )
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }

    private func positionSpotlightPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSApplication.shared.keyWindow?.screen ?? NSScreen.screens.first else {
            return
        }

        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private func registerCommands() {
        commandRegistry.register(
            SpotlightCommand(
                name: "new chrome window",
                aliases: ["chrome", "open chrome", "create chrome window", "google chrome"],
                action: { [weak self] in
                    self?.openGoogleChromeWindow()
                }
            )
        )
    }

    private func openGoogleChromeWindow() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        let bundleID = "com.google.Chrome"

        let chrome = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
        if chrome == nil {
            NSWorkspace.shared.launchApplication("Google Chrome")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.selectChromeNewWindow()
            }
            return
        }

        chrome?.activate(options: .activateIgnoringOtherApps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.selectChromeNewWindow()
        }
    }

    private func selectChromeNewWindow(retryCount: Int = 0) {
        let bundleID = "com.google.Chrome"
        guard let chrome = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            NSSound.beep()
            return
        }

        let pid = chrome.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var menuBarRef: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard menuBarResult == .success else {
            if retryCount < 5 {
                let delay = 0.3 * Double(retryCount + 1)
                chrome.activate(options: .activateIgnoringOtherApps)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.selectChromeNewWindow(retryCount: retryCount + 1)
                }
            } else {
                NSSound.beep()
            }
            return
        }

        let menuBar = menuBarRef as! AXUIElement
        guard let menuItem = findMenuItemByPath(in: menuBar, path: ["File", "New Window"]) else {
            NSSound.beep()
            return
        }

        let result = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
        if result != .success {
            NSSound.beep()
        }
    }

    private func findMenuItemByPath(in element: AXUIElement, path: [String]) -> AXUIElement? {
        var current = element
        for component in path {
            guard let child = findAXChild(named: component, in: current) else {
                return nil
            }
            current = child
        }
        return current
    }

    private func findAXChild(named name: String, in element: AXUIElement) -> AXUIElement? {
        var count: CFIndex = 0
        AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &count)
        guard count > 0 else { return nil }

        var childrenRef: CFArray?
        guard AXUIElementCopyAttributeValues(element, kAXChildrenAttribute as CFString, 0, count, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""

            if role == (kAXMenuRole as String) {
                if let found = findAXChild(named: name, in: child) { return found }
                continue
            }

            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            if (titleRef as? String) == name {
                return child
            }
        }
        return nil
    }
}

@main
struct FocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Focus", image: "MenuBarIcon") {
            VStack(alignment: .leading, spacing: 8) {
                Button("Open Focus Panel") {
                    appDelegate.showSpotlightInput()
                }

                Divider()

                Button("Quit Focus") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
            .frame(minWidth: 180)
        }
        .menuBarExtraStyle(.window)
    }
}
