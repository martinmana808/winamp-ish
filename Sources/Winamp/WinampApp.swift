import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app shows in the Dock and can take focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct WinampApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            PlayerView()
                .frame(minWidth: 275, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
