import SwiftUI
import AppKit

/// Design tokens for Jig's OpenUsage-inspired visual language.
///
/// The surface is a flat near-black canvas (`Theme.canvas`), not native
/// vibrancy — a deliberate departure from the system-chrome look so the app
/// reads as its own branded dashboard. Color still centers on one signal hue
/// (`Brand.signalOrange`); type is SF Pro for chrome with SF Mono kept for
/// the things that are literally code — branch folders and paths. Everything
/// sits on an 8pt rhythm.
enum Theme {
    // MARK: Accent + state — brand signal, not the system accent
    static let accent = Brand.signalOrange
    static let danger = Color(nsColor: .systemRed)

    // MARK: Text ramp — semantic, adapts to appearance & accessibility
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary  = Color(nsColor: .tertiaryLabelColor)

    // MARK: Fills + lines
    static let hover    = Brand.tintHover
    static let selected = Brand.tintSelected
    static let hairline = Color(nsColor: .separatorColor)

    // MARK: Canvas — flat near-black surface (replaces native vibrancy)
    static let canvas = Color(red: 0.05, green: 0.05, blue: 0.055)

    /// One step lighter than `canvas` — gives cards/rows visible separation
    /// from the page behind them instead of sitting at the identical tone.
    static let surfaceRaised = Color(red: 0.11, green: 0.11, blue: 0.12)

    // MARK: Layout
    static let railWidth: CGFloat = 64

    // MARK: Status dots — distinct from `accent` so a dirty dot never reads
    // as a selection indicator.
    static let dotClean = Color(nsColor: .systemGreen)
    static let dotDirty = Color(nsColor: .systemRed)

    // MARK: Corner radii (continuous, like AppKit controls)
    static let rControl: CGFloat = 7
    static let rRow: CGFloat = 7

    /// Monospace face — reserved for branch folders and paths, the app's code.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Brand tokens

/// Jig brand tokens. The one signal color over the native graphite/vibrancy
/// surface; everything else stays semantic + system.
enum Brand {
    /// #FF6A1A — the single brand accent.
    static let signalOrange = Color(red: 1.0, green: 0.416, blue: 0.102)
    /// #DB4D0D — deeper orange, used only as the bottom of the primary gradient.
    static let signalDeep   = Color(red: 0.859, green: 0.302, blue: 0.051)
    /// Accent-tinted interaction fills over vibrancy (replace the old gray opacities).
    static let tintHover    = signalOrange.opacity(0.10)
    static let tintSelected = signalOrange.opacity(0.16)
    /// The selected-row spine color.
    static let spine        = signalOrange
    /// Primary-button fill — a subtle vertical orange gradient.
    static let accentGradient = LinearGradient(
        colors: [signalOrange, signalDeep],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Button styles

/// Primary action — system-accent fill, white label, gentle press scale.
/// The one emphasized control on screen.
struct AccentPill: ButtonStyle {
    var size: CGFloat = 13
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.rControl, style: .continuous)
                    .fill(Brand.accentGradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
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
                .foregroundStyle(Theme.textSecondary)
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

// MARK: - Liquid Glass tabs

/// A tab selector whose selected indicator is a Liquid Glass capsule that
/// slides between tabs (macOS 26+). Before 26 it degrades to a solid accent
/// capsule. Used where a binary/short mode choice reads better as tabs than as
/// a system segmented control.
struct LiquidTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let tabs: [(value: Value, title: String)]
    var selectedFill: Color = Theme.accent
    var selectedTextColor: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.value) { tab in
                let isSel = selection == tab.value
                Button {
                    if reduceMotion { selection = tab.value }
                    else { withAnimation(.snappy(duration: 0.3)) { selection = tab.value } }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSel ? selectedTextColor : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background {
                            if isSel {
                                GlassIndicator(fill: selectedFill).matchedGeometryEffect(id: "liquidTab", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// The sliding selected pill — real Liquid Glass on macOS 26, solid accent before.
private struct GlassIndicator: View {
    var fill: Color = Theme.accent
    var body: some View {
        if #available(macOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(fill).interactive(), in: .capsule)
        } else {
            Capsule(style: .continuous).fill(fill)
        }
    }
}

/// Quiet secondary action — a tinted ghost that reads as a control without
/// competing with the accent.
struct GhostPill: ButtonStyle {
    var size: CGFloat = 13
    var danger: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(danger ? Theme.danger : Theme.textPrimary)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.rControl, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.13 : 0.07))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Brand motifs

/// A 3pt accent bar marking a selected row's leading edge — the signature motif.
struct AccentSpine: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Brand.spine)
            .frame(width: 3)
            .frame(maxHeight: .infinity)
    }
}
