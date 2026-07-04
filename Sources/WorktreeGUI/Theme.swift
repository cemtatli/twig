import SwiftUI
import AppKit

/// Thin semantic-token + shared-helper layer for Twig.
///
/// Twig is an Apple-native menubar utility: it sits on the platform's own design
/// system — semantic fonts (`.title3` / `.body` / `.caption`), semantic colors
/// (`Color.primary` / `.secondary` / `.tertiary`), the **system accent** for all
/// selection and emphasis, and system materials (`.listStyle(.sidebar)`
/// vibrancy, grouped `Form`). There is intentionally no owned color/control
/// design system here — that was the old "OpenUsage" direction and it read as
/// generic. The brand survives only as the `TwigMark` logo and the menubar icon
/// (the one allowed brand-orange use, in `Brand.signalOrange`).
///
/// This file holds just the few things the platform does not give for free: the
/// git clean/dirty status colors, a mono-font helper reserved for paths/log, the
/// installed-app discovery, and the sidebar toggle control.
enum Theme {
    // MARK: Status dots — git worktree clean/dirty. Semantic system green/red so
    // they adapt to appearance, accent, and accessibility.
    static let dotClean = Color(nsColor: .systemGreen)
    static let dotDirty = Color(nsColor: .systemRed)

    /// Error/destructive text color (not buttons — buttons use `role:
    /// .destructive`). Semantic system red.
    static let danger = Color(nsColor: .systemRed)

    /// Monospace face — reserved for read-only filesystem paths and terminal log
    /// output. Never for input fields or chrome labels (those are SF Pro).
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Brand

/// The Twig brand. Reduced to the single logo color — Twig uses the system accent
/// for every control, so the brand orange appears ONLY on the `TwigMark` glyph
/// and the menubar icon.
enum Brand {
    /// #FF6A1A — the Twig logo orange. Logo/menubar-icon use only.
    static let signalOrange = Color(red: 1.0, green: 0.416, blue: 0.102)
}

// MARK: - Sidebar toggle

/// Collapses / expands the source-list sidebar. Lives in every pane header so
/// the sidebar can always be toggled regardless of which pane is showing.
struct SidebarToggle: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                state.sidebarCollapsed.toggle()
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.sidebarCollapsed ? state.t(.sidebarShow) : state.t(.sidebarHide))
        .accessibilityLabel(state.t(.sidebarLabel))
    }
}

// MARK: - Installed-app discovery

/// Resolves which terminal / editor apps are actually installed, so pickers
/// only offer real choices instead of a fixed menu. The candidate names are
/// just the universe to probe — what's shown is filtered to this machine.
enum InstalledApps {
    static let terminals = ["Terminal", "iTerm", "Warp", "Ghostty", "kitty",
                            "Alacritty", "WezTerm", "Hyper", "Tabby", "cmux"]
    static let editors = ["Cursor", "Visual Studio Code", "VSCodium", "Zed",
                          "Sublime Text", "Nova", "Xcode", "Fleet", "Windsurf"]

    static func installed(_ candidates: [String]) -> [String] {
        candidates.filter(isInstalled)
    }

    static func isInstalled(_ appName: String) -> Bool {
        if NSWorkspace.shared.fullPath(forApplication: appName) != nil { return true }
        return FileManager.default.fileExists(atPath: "/Applications/\(appName).app")
    }
}
