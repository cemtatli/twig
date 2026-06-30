import SwiftUI

@main
struct WorktreeGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Worktrees", systemImage: "arrow.triangle.branch") {
            MenuContentView().environmentObject(state)
        }
        .menuBarExtraStyle(.window)

        // Real windows (not sheets) — the MenuBarExtra popover is transient and
        // dismisses on focus loss, which breaks sheets and keyboard text entry.
        Window("Ayarlar", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)

        Window("Yeni Worktree", id: "new-worktree") {
            NewWorktreeView().environmentObject(state)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // dock ikonu yok, sadece menubar
    }
}
