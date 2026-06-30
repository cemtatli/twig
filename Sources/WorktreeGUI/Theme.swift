import SwiftUI
import AppKit

/// Design tokens, tuned to read as a first-party macOS menubar app.
///
/// The surface is native vibrancy (the desktop shows through, like Control
/// Center or the Wi-Fi popover), not a hardcoded near-black. Color follows the
/// system accent rather than a fixed brand hue, and type is SF Pro for chrome
/// with SF Mono kept for the things that are literally code — branch folders
/// and paths. Everything sits on an 8pt rhythm.
enum Theme {
    // MARK: Accent + state — follow the system, don't override it
    static let accent = Color.accentColor
    static let danger = Color(nsColor: .systemRed)

    // MARK: Text ramp — semantic, adapts to appearance & accessibility
    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary  = Color(nsColor: .tertiaryLabelColor)

    // MARK: Fills + lines
    static let hover    = Color.primary.opacity(0.06)
    static let selected = Color.primary.opacity(0.10)
    static let hairline = Color(nsColor: .separatorColor)

    // MARK: Corner radii (continuous, like AppKit controls)
    static let rControl: CGFloat = 7
    static let rRow: CGFloat = 7

    /// Monospace face — reserved for branch folders and paths, the app's code.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Vibrancy

/// Thin wrapper over `NSVisualEffectView` so panels blend with the desktop
/// behind the popover — the standard macOS material look. Honors the user's
/// "Reduce transparency" setting via the caller's fallback.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
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
                    .fill(Theme.accent.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
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
                        .foregroundStyle(isSel ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background {
                            if isSel {
                                GlassIndicator().matchedGeometryEffect(id: "liquidTab", in: ns)
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
    var body: some View {
        if #available(macOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: .capsule)
        } else {
            Capsule(style: .continuous).fill(Theme.accent)
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
