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
import UserNotifications

final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct SpotlightInputView: View {
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool
    let commandSuggestions: (String) -> [SpotlightCommand]
    let onSubmitSelection: (SpotlightCommand?) -> Void
    let onCancel: () -> Void

    private var visibleCommands: [SpotlightCommand] {
        commandSuggestions(query)
    }

    private var selectedCommand: SpotlightCommand? {
        guard !visibleCommands.isEmpty else {
            return nil
        }

        let safeIndex = min(max(selectedIndex, 0), visibleCommands.count - 1)
        return visibleCommands[safeIndex]
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Focus")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("Type a command...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                )
                .focused($isFocused)
                .onSubmit {
                    let commandToRun = selectedCommand
                    query = ""
                    selectedIndex = 0
                    onSubmitSelection(commandToRun)
                }
                .onKeyPress(.escape) {
                    query = ""
                    selectedIndex = 0
                    onCancel()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !visibleCommands.isEmpty else {
                        return .handled
                    }
                    selectedIndex = max(selectedIndex - 1, 0)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard !visibleCommands.isEmpty else {
                        return .handled
                    }
                    selectedIndex = min(selectedIndex + 1, visibleCommands.count - 1)
                    return .handled
                }
                .onChange(of: query) {
                    selectedIndex = 0
                }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(visibleCommands.enumerated()), id: \.element.id) { index, command in
                    Text(command.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(index == selectedIndex ? Color.white : Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            index == selectedIndex
                                ? Color.accentColor.opacity(0.9)
                                : Color(nsColor: .windowBackgroundColor).opacity(0.55)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }
}

struct SpotlightCommand {
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

    func matchingCommands(for input: String) -> [SpotlightCommand] {
        let query = normalize(input)

        if query.isEmpty {
            return commands
        }

        return commands
            .compactMap { command -> (command: SpotlightCommand, score: Int)? in
                let bestScore = command.searchableTerms
                    .compactMap { fuzzyScore(query: query, candidate: normalize($0)) }
                    .max()

                guard let bestScore, bestScore > 0 else {
                    return nil
                }

                return (command, bestScore)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.command.name < rhs.command.name
                }
                return lhs.score > rhs.score
            }
            .map(\.command)
    }

    func execute(_ command: SpotlightCommand) {
        command.action()
    }

    private func normalize(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // Subsequence matcher with bonuses for contiguous and word-start matches.
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

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    private var spotlightPanel: SpotlightPanel?
    private let commandRegistry = CommandRegistry()
    static var shared: AppDelegate?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.shared = self
        registerCommands()
        requestNotificationPermission()
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

        let panel = spotlightPanel ?? makeSpotlightPanel()
        spotlightPanel = panel

        positionSpotlightPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func makeSpotlightPanel() -> SpotlightPanel {
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let rootView = SpotlightInputView(
            commandSuggestions: { query in
                self.commandRegistry.matchingCommands(for: query)
            },
            onSubmitSelection: { selectedCommand in
                guard let selectedCommand else {
                    NSSound.beep()
                    panel.orderOut(nil)
                    return
                }

                self.commandRegistry.execute(selectedCommand)
                panel.orderOut(nil)
            },
            onCancel: {
                panel.orderOut(nil)
            }
        )

        panel.contentView = NSHostingView(rootView: rootView)
        return panel
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
                name: "show notification",
                aliases: ["show notif", "notification", "this is a notif"],
                action: { [weak self] in
                    self?.showNotification(message: "this is a notif")
                }
            )
        )
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[Focus] Notification permission error: \(error)")
                return
            }
            print("[Focus] Notification permission granted: \(granted)")
        }
    }

    private func showNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Focus] Failed to post notification: \(error)")
            }
        }
    }
}

@main
struct FocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        MenuBarExtra("Focus", systemImage: "play.fill") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .menuBarExtraStyle(.window)
    }
}
