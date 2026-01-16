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

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    static var shared: AppDelegate?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.shared = self
        registerGlobalHotKey()
    }
    
    func registerGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4355) // "FOCU"
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            print("[Focus] Hotkey pressed!")
            DispatchQueue.main.async {
                AppDelegate.shared?.toggleMenuBarWindow()
            }
            return noErr
        }
        
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        print("[Focus] InstallEventHandler status: \(installStatus)")
        
        // Cmd+Shift+Space: kVK_Space = 49, cmdKey = 256, shiftKey = 512
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let registerStatus = RegisterEventHotKey(UInt32(kVK_Space), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        print("[Focus] RegisterEventHotKey status: \(registerStatus), hotKeyRef: \(String(describing: hotKeyRef))")
    }
    
    func toggleMenuBarWindow() {
        // Find the status item button and simulate a click
        if let button = NSApp.windows
            .compactMap({ $0.value(forKey: "statusItem") as? NSStatusItem })
            .first?.button {
            button.performClick(nil)
        } else {
            // Fallback: post a click event to the menu bar area
            NSApp.activate(ignoringOtherApps: true)
            // Try to find and click the status bar button via accessibility
            for window in NSApp.windows {
                if window.className.contains("NSStatusBarWindow") {
                    if let contentView = window.contentView {
                        let point = NSPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
                        let mouseDown = NSEvent.mouseEvent(with: .leftMouseDown, location: window.convertPoint(toScreen: point), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0)
                        let mouseUp = NSEvent.mouseEvent(with: .leftMouseUp, location: window.convertPoint(toScreen: point), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1.0)
                        if let down = mouseDown, let up = mouseUp {
                            NSApp.sendEvent(down)
                            NSApp.sendEvent(up)
                        }
                    }
                    break
                }
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
