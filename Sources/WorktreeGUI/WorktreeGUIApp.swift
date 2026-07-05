import SwiftUI
import AppKit

@main
struct WorktreeGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(state)
        } label: {
            Image(nsImage: TwigGlyph.menuBarImage())
                .accessibilityLabel("Twig")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // dock ikonu yok, sadece menubar

        // MenuBarExtra(.window) popover'ı sistemce menubar ikonunun altına,
        // ikona hizalı açılır. İstenen: notch'un altında, yatayda ortalı. Popover
        // penceresi key olduğunda yakalayıp X'i ekran ortasına taşı.
        keyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil, queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            // Popover'ın penceresi private bir sınıf (NSMenuBarExtraWindow); ada
            // göre süz ki NSOpenPanel gibi diğer pencereleri oynatmayalım.
            guard String(describing: type(of: window)).contains("MenuBarExtra") else { return }
            AppDelegate.centerUnderNotch(window)
        }
    }

    /// Pencereyi notch'lu ekranda (yoksa ana ekranda) yatayda ortalar, üstünü
    /// menubar'ın hemen altına oturtur.
    static func centerUnderNotch(_ window: NSWindow) {
        DispatchQueue.main.async {
            let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
                ?? NSScreen.main
            guard let screen else { return }
            let frame = screen.frame
            let size = window.frame.size
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY   // üst inset
            let x = frame.midX - size.width / 2
            let y = frame.maxY - menuBarHeight - size.height
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
