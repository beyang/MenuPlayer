//
//  ContentView.swift
//  MenuPlayer
//
//  Created by Beyang Liu on 7/19/25.
//

import SwiftUI
import WebKit

struct ActivityItem: Identifiable {
    let id = UUID()
    let description: String
    let startTime: Date
    var endTime: Date?
    
    var duration: String {
        guard let end = endTime else {
            return "ongoing"
        }
        let interval = end.timeIntervalSince(startTime)
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: (24 * 60 * 60))) / (60 * 60))
        let minutes = Int((interval.truncatingRemainder(dividingBy: (60 * 60))) / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        
        var components: [String] = []
        if days > 0 { components.append("\(days)d") }
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 { components.append("\(minutes)m") }
        if seconds > 0 || components.isEmpty { components.append("\(seconds)s") }
        
        return components.joined(separator: " ")
    }
    
    var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startTime)
        
        if let end = endTime {
            let endStr = formatter.string(from: end)
            return "\(start) - \(endStr)"
        } else {
            return "\(start) - now"
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

struct ActivityListView: View {
    @Binding var activities: [ActivityItem]
    @State private var newActivityText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Personal Log")
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Activity list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(activities.reversed()) { activity in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.description)
                                    .font(.system(size: 13))
                                    .lineLimit(2)
                                
                                Text(activity.timeDisplay)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(activity.duration)
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(activity.endTime == nil ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            
            // Input area
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("What are you doing now?", text: $newActivityText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addNewActivity()
                        }
                    
                    Button("Add") {
                        addNewActivity()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newActivityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Clear") {
                        clearAllActivities()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(activities.isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func addNewActivity() {
        let trimmed = newActivityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let now = Date()
        
        // End the previous activity
        if let lastIndex = activities.indices.last,
           activities[lastIndex].endTime == nil {
            activities[lastIndex].endTime = now
        }
        
        // Add new activity
        let newActivity = ActivityItem(description: trimmed, startTime: now)
        activities.append(newActivity)
        
        newActivityText = ""
    }
    
    private func clearAllActivities() {
        activities.removeAll()
    }
}

struct ContentView: View {
    @State private var urlString = "https://www.google.com"
    @State private var currentURL: URL = URL(string: "https://www.google.com")!
    @State private var activities: [ActivityItem] = []
    
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
            
            // Main content area with WebView and Activity List
            HStack(spacing: 0) {
                // WebView - takes up 2/3 of the space
                WebView(url: currentURL)
                    .background(Color.white)
                    .frame(minWidth: 400)
                
                // Divider
                Divider()
                
                // Activity List - takes up 1/3 of the space
                ActivityListView(activities: $activities)
                    .frame(width: 300)
            }
            
            // Bottom toolbar
            HStack {
                Button("Refresh") {
                    currentURL = currentURL
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
        .frame(minWidth: 900, minHeight: 500)
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
