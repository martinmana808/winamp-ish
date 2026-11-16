import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Files opened from Finder ("Open With", drop on the Dock icon).
    func application(_ application: NSApplication, open urls: [URL]) {
        Player.shared.add(urls, playFirst: true)
    }
}

@main
struct WinampApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var player = Player.shared

    var body: some Scene {
        Window("Winamp", id: "main") {
            ContentView().environmentObject(player)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Agregar música…") { player.openPanel() }
                    .keyboardShortcut("o")
                Button("Exportar playlist…") { player.exportPanel() }
                    .keyboardShortcut("e")
                    .disabled(player.tracks.isEmpty)
                Divider()
                Button("Vaciar playlist") { player.clear() }
                    .disabled(player.tracks.isEmpty)
            }
        }
    }
}
