import SwiftUI
import AppKit

/// Design tokens. The app speaks in monospace — branches and paths are the
/// content, so the type that carries them is the app's voice. Surfaces are
/// flat near-black (no translucency, which muddied the panel over a bright
/// desktop); the rail sits a shade darker than the panel for a crisp split.
/// Lime is the single signal: active tab and primary action, nothing else.
enum Theme {
    // MARK: Surfaces
    static let railBG  = Color(red: 0.039, green: 0.043, blue: 0.055) // #0A0B0E
    static let panelBG = Color(red: 0.063, green: 0.071, blue: 0.086) // #101216

    // MARK: Signal + state
    /// The one accent. Active tab, primary button — used sparingly.
    static let accent = Color(red: 0.722, green: 0.902, blue: 0.290)  // #B8E64A
    static let danger = Color(red: 0.898, green: 0.325, blue: 0.294)  // #E5534B

    // MARK: Text ramp
    static let textPrimary   = Color(red: 0.902, green: 0.910, blue: 0.922) // #E6E8EB
    static let textSecondary = Color(red: 0.541, green: 0.565, blue: 0.600) // #8A9099
    static let textTertiary  = Color(red: 0.329, green: 0.349, blue: 0.380) // #545961

    static let hover    = Color.white.opacity(0.05)
    static let selected = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.08)

    /// Monospace face for branches, task names, and paths — the app's voice.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Primary action — the lime pill with dark text. The one loud control.
struct AccentPill: ButtonStyle {
    var size: CGFloat = 13
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}

/// Quiet secondary action — ghost pill that reads as a control without shouting.
struct GhostPill: ButtonStyle {
    var size: CGFloat = 13
    var danger: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(danger ? Theme.danger : Theme.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(Theme.hover))
            .overlay(Capsule().strokeBorder(
                (danger ? Theme.danger : Theme.textSecondary).opacity(0.22), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
