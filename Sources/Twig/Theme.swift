import SwiftUI
import AppKit

/// Twig'in Keeby-dili koyu tasarım sistemi: siyah kanvas üzerinde yüzen
/// yuvarlatılmış paneller, kart dışı gri section başlıkları, kart içi hairline
/// satırlar, gradient ikon karoları. Uygulama her zaman koyu
/// (`.preferredColorScheme(.dark)` kökte) — açık tema yok.
/// Referans: getkeeby.com + spec 2026-07-04-twig-rebrand-keeby-restyle.
enum Theme {
    // MARK: Yüzeyler
    /// Pencere zemini — paneller arasındaki "boşluk" rengi.
    static let canvas = Color(red: 0.039, green: 0.039, blue: 0.039)      // #0A0A0A
    /// Yüzen kart dolgusu.
    static let panel = Color(red: 0.110, green: 0.110, blue: 0.118)      // #1C1C1E
    /// Kart kenarına 1px iç kontur — koyu zeminde kenar tanımı.
    static let panelStroke = Color.white.opacity(0.05)
    /// Seçili satır dolgusu (Keeby'nin seçili "General" satırı).
    static let rowSelected = Color(red: 0.173, green: 0.173, blue: 0.180) // #2C2C2E
    static let rowHover = Color.white.opacity(0.05)
    /// Kart içi satır ayırıcı.
    static let hairline = Color.white.opacity(0.07)

    // MARK: Vurgu + durum
    static let accent = Brand.signalOrange
    static let dotClean = Color(nsColor: .systemGreen)
    static let dotDirty = Color(nsColor: .systemRed)
    static let danger = Color(nsColor: .systemRed)

    /// Kart panel yarıçapı.
    static let panelRadius: CGFloat = 14

    /// Kartların DIŞINDA duran gri section başlığı (Keeby "Feel"/"Tone").
    static func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    /// Monospace — sadece salt-okunur yol ve log metni için.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Brand

/// Twig markası. #FF6A1A artık yalnız logo değil, uygulama geneli kontrol
/// vurgusu (toggle dolgusu, birincil buton, seçim vurguları).
enum Brand {
    /// #FF6A1A — Twig turuncusu.
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
