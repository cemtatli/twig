import SwiftUI
import AppKit

/// The Jig mark: a heavy "J" whose hook clamps a short bar — letter + tool.
/// Tints with the current foreground style so it works as a template glyph.
struct JigMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // The J — heavy, slightly condensed.
                Text("J")
                    .font(.system(size: s * 0.92, weight: .black, design: .rounded))
                    .frame(width: s, height: s)
                // The clamped bar across the J's hook (lower-left).
                RoundedRectangle(cornerRadius: s * 0.06, style: .continuous)
                    .frame(width: s * 0.30, height: s * 0.13)
                    .offset(x: -s * 0.20, y: s * 0.24)
            }
            .frame(width: s, height: s)
        }
    }
}

/// "Jig" wordmark for headers / empty state.
struct JigWordmark: View {
    var size: CGFloat = 17
    var body: some View {
        HStack(spacing: size * 0.28) {
            JigMark().frame(width: size * 1.05, height: size * 1.05)
            Text("Jig")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(-0.5)
        }
        .foregroundStyle(Theme.textPrimary)
    }
}

enum JigGlyph {
    /// Renders `JigMark` to a template NSImage so the menubar tints it like a
    /// native symbol (adapts to light/dark + selection).
    @MainActor static func menuBarImage(side: CGFloat = 18) -> NSImage {
        let renderer = ImageRenderer(content:
            JigMark().frame(width: side, height: side).foregroundStyle(.black))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: side, height: side))
        image.isTemplate = true
        return image
    }
}
