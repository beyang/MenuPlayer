//
//  ContentView.swift
//  MenuPlayer
//
//  Created by Beyang Liu on 7/19/25.
//

import SwiftUI
import WebKit

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
            
            // Main content area with WebView
            WebView(url: currentURL)
                .background(Color.white)
            
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
        .frame(minWidth: 600, minHeight: 400)
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
