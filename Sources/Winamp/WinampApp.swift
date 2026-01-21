import SwiftUI

@main
struct WinampApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerView()
                .frame(minWidth: 275, maxWidth: 275, minHeight: 400, maxHeight: .infinity)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}
