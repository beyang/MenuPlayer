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

struct ActiveTimer: Identifiable {
    let id: String
    let originalInput: String
    let endTime: Date

    var remainingTime: TimeInterval {
        endTime.timeIntervalSince(Date())
    }

    var isExpired: Bool {
        remainingTime <= 0
    }
}

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    let onChange: ((String) -> Void)?

    init(placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void, onChange: ((String) -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
        self.onChange = onChange
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .background(Color.black.opacity(0.1))
            .cornerRadius(4)
            .onSubmit {
                onSubmit()
            }
            .onChange(of: text) { newValue in
                onChange?(newValue)
            }
    }
}

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
    @State private var activeTimers: [ActiveTimer] = []
    @State private var timerUpdateTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and URL bar
            VStack(spacing: 12) {
                Text("MenuPlayer")
                    .font(.title2)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    StyledTextField(
                        placeholder: "Enter URL",
                        text: $urlString,
                        onSubmit: navigateToURL
                    )

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
            startTimerUpdateTimer()
        }
        .onDisappear {
            timerUpdateTimer?.invalidate()
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

                Text("notif <message> - Show notification")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("timer <time> - Set timer (5s, 5h, 8:00, 16:00, 5pm)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            // Active timers section
            if !activeTimers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Timers:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(activeTimers) { timer in
                        HStack {
                            Text(timer.originalInput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(formatRemainingTime(timer.remainingTime))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Button(action: {
                                cancelTimer(timer)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 16, height: 16)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.bottom, 8)
            }

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

                HStack(spacing: 4) {
                    Text(">")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    StyledTextField(
                        placeholder: "Enter command",
                        text: $commandInput,
                        onSubmit: processCommand,
                        onChange: { _ in
                            if !errorMessage.isEmpty {
                                errorMessage = ""
                            }
                        }
                    )
                }
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
        let commandContent = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear previous error
        errorMessage = ""

        guard !commandContent.isEmpty else {
            errorMessage = "Please enter a command"
            return
        }

        if commandContent.hasPrefix("notif ") {
            let message = String(commandContent.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                showNotification(title: "MenuPlayer", message: message)
                commandInput = ""
            } else {
                errorMessage = "notif command requires a message"
            }
        } else if commandContent.hasPrefix("timer ") {
            let timeString = String(commandContent.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !timeString.isEmpty {
                if let timeInterval = parseTimeString(timeString) {
                    scheduleTimer(timeInterval: timeInterval, originalInput: timeString)
                    commandInput = ""
                } else {
                    errorMessage = "Invalid time format. Use: 5s, 5h, 8:00, 16:00, or 5pm"
                }
            } else {
                errorMessage = "timer command requires a time specification"
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

//        // Also play a system alert sound as backup
//        DispatchQueue.main.async {
//            if let alertSound = NSSound(named: "Ping") {
//                alertSound.play()
//            } else {
//                NSSound.beep() // Fallback if Ping isn't available
//            }
//        }

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

    private func parseTimeString(_ timeString: String) -> TimeInterval? {
        let input = timeString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle duration formats (5s, 5m, 5h)
        if input.hasSuffix("s") {
            if let seconds = Double(String(input.dropLast())) {
                return seconds
            }
        } else if input.hasSuffix("m") {
            if let minutes = Double(String(input.dropLast())) {
                return minutes * 60
            }
        } else if input.hasSuffix("h") {
            if let hours = Double(String(input.dropLast())) {
                return hours * 3600
            }
        }

        // Handle absolute time formats (8:00, 16:00, 5pm)
        let now = Date()
        let calendar = Calendar.current

        // Handle PM times (5pm, 12pm)
        if input.hasSuffix("pm") {
            let timeStr = String(input.dropLast(2))
            if let hour = Int(timeStr) {
                let adjustedHour = hour == 12 ? 12 : hour + 12
                if let targetDate = calendar.date(bySettingHour: adjustedHour, minute: 0, second: 0, of: now) {
                    let interval = targetDate.timeIntervalSince(now)
                    return interval > 0 ? interval : interval + 24 * 3600 // Next day if time has passed
                }
            }
        }

        // Handle AM times (5am, 12am)
        if input.hasSuffix("am") {
            let timeStr = String(input.dropLast(2))
            if let hour = Int(timeStr) {
                let adjustedHour = hour == 12 ? 0 : hour
                if let targetDate = calendar.date(bySettingHour: adjustedHour, minute: 0, second: 0, of: now) {
                    let interval = targetDate.timeIntervalSince(now)
                    return interval > 0 ? interval : interval + 24 * 3600 // Next day if time has passed
                }
            }
        }

        // Handle 24-hour format (8:00, 16:30)
        if input.contains(":") {
            let components = input.split(separator: ":")
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                if let targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) {
                    let interval = targetDate.timeIntervalSince(now)
                    return interval > 0 ? interval : interval + 24 * 3600 // Next day if time has passed
                }
            }
        }

        return nil
    }

    private func scheduleTimer(timeInterval: TimeInterval, originalInput: String) {
        let timerId = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = "Timer"
        content.body = "Timer set for \(originalInput) has finished!"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: timerId,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to schedule timer: \(error.localizedDescription)"
                }
            } else {
                DispatchQueue.main.async {
                    let endTime = Date().addingTimeInterval(timeInterval)
                    let activeTimer = ActiveTimer(id: timerId, originalInput: originalInput, endTime: endTime)
                    self.activeTimers.append(activeTimer)
                }
                print("Timer scheduled for \(timeInterval) seconds")
            }
        }
    }

    private func startTimerUpdateTimer() {
        timerUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateActiveTimers()
        }
    }

    private func updateActiveTimers() {
        activeTimers.removeAll { $0.isExpired }
    }

    private func cancelTimer(_ timer: ActiveTimer) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id])
        activeTimers.removeAll { $0.id == timer.id }
    }

    private func formatRemainingTime(_ timeInterval: TimeInterval) -> String {
        if timeInterval <= 0 {
            return "00:00"
        }

        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
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
