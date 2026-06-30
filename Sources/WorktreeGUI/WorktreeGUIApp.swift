import SwiftUI

@main
struct WorktreeGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(state)
                .preferredColorScheme(.dark)
        } label: {
            Image(nsImage: JigGlyph.menuBarImage())
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // dock ikonu yok, sadece menubar
    }
}
