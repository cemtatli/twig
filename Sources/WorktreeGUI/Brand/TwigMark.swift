import SwiftUI
import AppKit

/// The Twig mark: a diagonal stem with two round-tipped offshoots — a small
/// branch, the git-worktree metaphor. Pure `Path`, tints with the current
/// foreground style so it works as a template glyph at 18 px and at 512 px.
struct TwigMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let w = s * 0.13                      // stroke weight
            ZStack(alignment: .topLeading) {
                Path { p in
                    // Gövde — sol-alt'tan sağ-üst'e.
                    p.move(to: CGPoint(x: 0.30 * s, y: 0.90 * s))
                    p.addLine(to: CGPoint(x: 0.66 * s, y: 0.10 * s))
                    // Sağ filiz.
                    p.move(to: stemPoint(0.40, s))
                    p.addLine(to: CGPoint(x: 0.88 * s, y: 0.36 * s))
                    // Sol filiz.
                    p.move(to: stemPoint(0.66, s))
                    p.addLine(to: CGPoint(x: 0.28 * s, y: 0.18 * s))
                }
                .stroke(style: StrokeStyle(lineWidth: w, lineCap: .round))
                // Tomurcuklar — filiz uçlarında hafif büyük noktalar.
                bud(at: CGPoint(x: 0.88 * s, y: 0.36 * s), w: w)
                bud(at: CGPoint(x: 0.28 * s, y: 0.18 * s), w: w)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func bud(at point: CGPoint, w: CGFloat) -> some View {
        Circle()
            .frame(width: w * 1.6, height: w * 1.6)
            .position(point)
    }

    /// Gövde üzerinde t (0=alt, 1=üst) noktası.
    private func stemPoint(_ t: CGFloat, _ s: CGFloat) -> CGPoint {
        CGPoint(x: (0.30 + 0.36 * t) * s, y: (0.90 - 0.80 * t) * s)
    }
}

/// "Twig" wordmark for headers / empty state.
struct TwigWordmark: View {
    var size: CGFloat = 17
    var body: some View {
        HStack(spacing: size * 0.28) {
            TwigMark().frame(width: size * 1.05, height: size * 1.05)
            Text("Twig")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(-0.5)
        }
        .foregroundStyle(.primary)
    }
}

enum TwigGlyph {
    /// Renders `TwigMark` to a template NSImage so the menubar tints it like a
    /// native symbol (adapts to light/dark + selection).
    @MainActor static func menuBarImage(side: CGFloat = 18) -> NSImage {
        let renderer = ImageRenderer(content:
            TwigMark().frame(width: side, height: side).foregroundStyle(.black))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: side, height: side))
        image.isTemplate = true
        return image
    }
}
