//
//  ContentView.swift
//  MenuPlayer
//
//  Created by Beyang Liu on 7/19/25.
//

import SwiftUI
import WebKit
import UserNotifications
import AppKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        print("WebView created")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        print("Loading URL: \(url)")
        nsView.load(request)
    }
}

struct ContentView: View {
    @State private var urlString = "https://www.google.com"
    @State private var currentURL: URL = URL(string: "https://www.google.com")!
    @State private var commandInput = ""
    @State private var showingCommandPanel = true
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and URL bar
            VStack(spacing: 12) {
                Text("MenuPlayer")
                    .font(.title2)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    TextField("Enter URL", text: $urlString)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            navigateToURL()
                        }

                    Button("Go") {
                        navigateToURL()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            // Main content area with WebView and Command Panel
            HStack(spacing: 0) {
                WebView(url: currentURL)
                    .background(Color.white)

                if showingCommandPanel {
                    commandPanel
                        .frame(width: 300)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }

            // Bottom toolbar
            HStack {
                Button("Refresh") {
                    currentURL = currentURL
                }
                .buttonStyle(.borderless)

                Button(showingCommandPanel ? "Hide Panel" : "Show Panel") {
                    showingCommandPanel.toggle()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            requestNotificationPermission()
        }
    }

    private var commandPanel: some View {
        VStack(spacing: 0) {
            // Command panel header
            HStack {
                Text("Command Panel")
                    .font(.headline)
                    .padding(.leading)

                Spacer()

                Button(action: {
                    showingCommandPanel.toggle()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.separatorColor).opacity(0.1))

            // Command area
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Commands:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("> notif <message> - Show notification")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Command input at bottom
            VStack(spacing: 8) {
                // Error message display
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }

                TextField("Enter command (prefix with '>')", text: $commandInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        processCommand()
                    }
                    .onChange(of: commandInput) {
                        if !errorMessage.isEmpty {
                            errorMessage = ""
                        }
                    }

                Button("Execute") {
                    processCommand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    private func processCommand() {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear previous error
        errorMessage = ""

        guard command.hasPrefix(">") else {
            errorMessage = "Commands must start with '>'"
            return
        }

        let commandContent = String(command.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)

        if commandContent.hasPrefix("notif ") {
            let message = String(commandContent.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                showNotification(title: "MenuPlayer", message: message)
                commandInput = ""
            } else {
                errorMessage = "notif command requires a message"
            }
        } else {
            let unknownCmd = commandContent.split(separator: " ").first ?? ""
            errorMessage = "Unknown command: '\(unknownCmd)'"
        }

        if errorMessage.isEmpty {
            commandInput = ""
        }
    }

    private func showNotification(title: String, message: String) {
        print("Showing notification - Title: '\(title)', Message: '\(message)'")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default

        // Also play a system alert sound as backup
        DispatchQueue.main.async {
            if let alertSound = NSSound(named: "Ping") {
                alertSound.play()
            } else {
                NSSound.beep() // Fallback if Ping isn't available
            }
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            } else {
                print("Notification added successfully")
            }
        }
    }

    private func navigateToURL() {
        var processedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if URL has a scheme
        if !processedURL.contains("://") {
            // Add https:// if no scheme is provided
            processedURL = "https://" + processedURL
            // Update the text field to show the complete URL
            urlString = processedURL
        }

        if let url = URL(string: processedURL) {
            currentURL = url
        }
    }
}

#Preview {
    ContentView()
}
