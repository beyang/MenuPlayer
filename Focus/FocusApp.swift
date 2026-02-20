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

struct SpotlightInputView: View {
    @State private var query = ""
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

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
                    onSubmit(query)
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
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
            isFocused = true
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    private var spotlightPanel: SpotlightPanel?
    static var shared: AppDelegate?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.shared = self
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 160),
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
            onSubmit: { value in
                print("[Focus] Spotlight query: \(value)")
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
