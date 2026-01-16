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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerGlobalHotKey()
    }
    
    func registerGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4355) // "FOCU"
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let statusItem = NSApp.windows.first(where: { $0.className.contains("NSStatusBarWindow") || $0.title.isEmpty }) {
                    statusItem.makeKeyAndOrderFront(nil)
                }
                NotificationCenter.default.post(name: NSNotification.Name("ToggleFocusWindow"), object: nil)
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        
        // Cmd+Shift+Space: kVK_Space = 49, cmdKey = 256, shiftKey = 512
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(UInt32(kVK_Space), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
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
