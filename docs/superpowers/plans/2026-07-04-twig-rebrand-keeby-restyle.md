# Twig Rebrand + Keeby-Style Dark Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the app from Jig to **Twig** (new twig glyph + icon) and restyle the entire popover to the Keeby design language: dark-only, floating rounded panels on a near-black canvas, gradient icon tiles, gray section labels outside cards, hairline rows inside cards, pixel-faithful custom controls.

**Architecture:** `WorktreeCore` untouched. `WorktreeGUI` gets: rewritten `Theme.swift` (owned dark token set), new `Controls.swift` (custom controls), `Brand/TwigMark.swift` (replaces `JigMark.swift`), and restyled `MenuContentView` / `NewWorktreeView` / `SettingsView`. Behavior (shortcuts, reorder, context menus, AppState API) unchanged.

**Tech Stack:** SwiftUI (macOS 14+), SwiftPM. No new dependencies. No linter.

**Spec:** `docs/superpowers/specs/2026-07-04-twig-rebrand-keeby-restyle-design.md` — read it first.

## Global Constraints

- App display name: **Twig** (targets stay `WorktreeGUI`/`WorktreeCore`; bundle id stays `com.cem.worktreegui`; config path stays `~/.config/worktree-gui/config.json`).
- Brand/accent: **#FF6A1A** (`Brand.signalOrange`) — now the app-wide control accent.
- Dark only: `.preferredColorScheme(.dark)` on the popover root.
- Panel radius **14** continuous; canvas `#0A0A0A`; panel `#1C1C1E`; selected row `#2C2C2E`; hairline white 7%.
- GUI target has **no unit tests** (all tests are WorktreeCoreTests). Verification per task = `swift build` clean + `swift test` green + visual check where noted.
- Comments: match surrounding language (Turkish/English mixed). UI strings stay in the L10n system — no hardcoded user-facing strings.
- No behavior changes: `handleKey`, 1-9 select, Tab/arrow cycling, drag-reorder gesture, context menus, hover row actions, removal confirm flow, sidebar collapse all keep working.
- Commit after each task.

---

### Task 1: Brand — TwigMark glyph, wordmark, menubar image, app name, icon script

**Files:**
- Create: `Sources/WorktreeGUI/Brand/TwigMark.swift`
- Delete: `Sources/WorktreeGUI/Brand/JigMark.swift`
- Modify: `Sources/WorktreeGUI/WorktreeGUIApp.swift` (lines 13–14)
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift` (lines 115, 265, 322, 432: `JigMark`→`TwigMark`, `JigWordmark`→`TwigWordmark`)
- Modify: `Sources/WorktreeGUI/Views/NewWorktreeView.swift` (line 26)
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift` (line 148)
- Modify: `scripts/build-app.sh` (line 10: `APP_DISPLAY="Twig"`)
- Modify: `scripts/make-icon.swift` (replace J drawing with twig path)

**Interfaces:**
- Produces: `TwigMark: View` (tints with foreground style, square, scalable), `TwigWordmark(size: CGFloat): View`, `TwigGlyph.menuBarImage(side:) -> NSImage` (template). Later tasks reference `TwigMark` only.

- [ ] **Step 1: Write `TwigMark.swift`**

```swift
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
                    p.move(to: CGPoint(x: 0.28 * s, y: 0.90 * s))
                    p.addLine(to: CGPoint(x: 0.72 * s, y: 0.10 * s))
                    // Sağ filiz.
                    p.move(to: stemPoint(0.42, s))
                    p.addLine(to: CGPoint(x: 0.88 * s, y: 0.48 * s))
                    // Sol filiz.
                    p.move(to: stemPoint(0.68, s))
                    p.addLine(to: CGPoint(x: 0.18 * s, y: 0.20 * s))
                }
                .stroke(style: StrokeStyle(lineWidth: w, lineCap: .round))
                // Tomurcuklar — filiz uçlarında hafif büyük noktalar.
                bud(at: CGPoint(x: 0.88 * s, y: 0.48 * s), w: w)
                bud(at: CGPoint(x: 0.18 * s, y: 0.20 * s), w: w)
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
        CGPoint(x: (0.28 + 0.44 * t) * s, y: (0.90 - 0.80 * t) * s)
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
```

- [ ] **Step 2: Delete `JigMark.swift`, update all call sites**

`git rm Sources/WorktreeGUI/Brand/JigMark.swift`. Then mechanical rename at the call sites listed above: `JigMark()` → `TwigMark()`, `JigWordmark(size: 22)` → `TwigWordmark(size: 22)`, `JigGlyph.menuBarImage()` → `TwigGlyph.menuBarImage()`, `.accessibilityLabel("Jig")` → `.accessibilityLabel("Twig")`. In `Theme.swift` doc comments, replace the word Jig with Twig (comment text only — Task 2 rewrites this file anyway, so a minimal pass is fine).

- [ ] **Step 3: `build-app.sh` + `make-icon.swift`**

`build-app.sh` line 10: `APP_DISPLAY="Twig"`.

In `make-icon.swift`, keep the gradient tile block, replace everything from the `// White clamp-J` comment through `bar.fill()` with (AppKit y-axis is flipped vs SwiftUI, so the stem goes bottom-left → top-right with increasing y):

```swift
// White twig: diagonal stem + two round-tipped offshoots (mirrors TwigMark).
NSColor.white.setStroke()
NSColor.white.setFill()
let w = side * 0.13 * 0.86            // stroke weight, scaled to tile
func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    // TwigMark unit coords (y-down) -> icon coords (y-up), inset to the tile.
    NSPoint(x: side * (0.07 + 0.86 * x), y: side * (0.07 + 0.86 * (1 - y)))
}
func stem(_ t: CGFloat) -> NSPoint { pt(0.28 + 0.44 * t, 0.90 - 0.80 * t) }
let path = NSBezierPath()
path.lineWidth = w
path.lineCapStyle = .round
path.move(to: pt(0.28, 0.90)); path.line(to: pt(0.72, 0.10))
path.move(to: stem(0.42));     path.line(to: pt(0.88, 0.48))
path.move(to: stem(0.68));     path.line(to: pt(0.18, 0.20))
path.stroke()
for budAt in [pt(0.88, 0.48), pt(0.18, 0.20)] {
    let r = w * 0.8
    NSBezierPath(ovalIn: NSRect(x: budAt.x - r, y: budAt.y - r,
                                width: r * 2, height: r * 2)).fill()
}
```

- [ ] **Step 4: Verify**

Run: `swift build && swift test`
Expected: build clean, all tests pass (Core untouched).
Run: `swift scripts/make-icon.swift /tmp/twig-icon.png && open /tmp/twig-icon.png` — glyph must read as a twig, centered, no clipping.
Run: `grep -rn "Jig" Sources/ scripts/` — expect **zero** hits (comments included).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: rebrand Jig -> Twig (glyph, wordmark, menubar icon, app name, icon script)"
```

---

### Task 2: Theme tokens + custom Keeby controls

**Files:**
- Rewrite: `Sources/WorktreeGUI/Theme.swift`
- Create: `Sources/WorktreeGUI/Controls.swift`

**Interfaces:**
- Consumes: `TwigMark` (Task 1), `Brand.signalOrange`.
- Produces (used verbatim by Tasks 3–5):
  - `Theme.canvas/panel/panelStroke/rowSelected/rowHover/hairline/accent` (Color), `Theme.sectionLabel(_ text: String) -> some View`, existing `Theme.dotClean/dotDirty/danger/mono()` kept, `SidebarToggle` kept.
  - `FloatingPanel<Content: View>(content:)` — panel container.
  - `IconTile(systemName: String?, color: Color, side: CGFloat = 28)` and `IconTile(glyph: some View, color: Color, side: CGFloat)` variant via `init(color:side:@ViewBuilder glyph:)`.
  - `TwigToggle(isOn: Binding<Bool>)`.
  - `PillBadge(_ text: String)`.
  - `BorderedPillButton(_ title: String, systemImage: String? = nil, action:)`.
  - `SettingsRow<Trailing: View>(title: String, subtitle: String? = nil, showsHairline: Bool = true, @ViewBuilder trailing:)`.
  - `TilePalette.color(for name: String) -> Color` — stable per-name tile color.

- [ ] **Step 1: Rewrite `Theme.swift`**

Keep `SidebarToggle` and `InstalledApps` exactly as they are (move untouched). Replace the header doc + `Theme`/`Brand` enums with:

```swift
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
```

(Then the unchanged `SidebarToggle` + `InstalledApps` sections follow.)

- [ ] **Step 2: Create `Controls.swift`**

```swift
import SwiftUI

// MARK: - FloatingPanel

/// Keeby yüzen kartı: koyu dolgu, 14pt sürekli köşe, 1px iç kontur.
struct FloatingPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                    .strokeBorder(Theme.panelStroke, lineWidth: 1)
            )
    }
}

// MARK: - IconTile

/// Yuvarlatılmış kare gradient ikon karosu (Keeby sidebar ikonları).
struct IconTile<Glyph: View>: View {
    let color: Color
    var side: CGFloat = 28
    @ViewBuilder var glyph: Glyph

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [color.brightened(0.18), color],
                                     startPoint: .top, endPoint: .bottom))
            glyph
                .font(.system(size: side * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)   // dekoratif — etiket her zaman yanındaki metin
    }
}

extension IconTile where Glyph == Image {
    init(systemName: String, color: Color, side: CGFloat = 28) {
        self.init(color: color, side: side) { Image(systemName: systemName) }
    }
}

extension Color {
    /// Gradient üst durağı için hafif aydınlatma.
    func brightened(_ amount: Double) -> Color {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return Color(red: min(1, ns.redComponent + amount),
                     green: min(1, ns.greenComponent + amount),
                     blue: min(1, ns.blueComponent + amount))
    }
}

// MARK: - TilePalette

/// Repo başına deterministik karo rengi — isim hash'i çalıştırmalar arası
/// stabil olsun diye djb2 (Swift `hashValue` seed'li, kullanma).
enum TilePalette {
    static let colors: [Color] = [
        Color(red: 0.94, green: 0.31, blue: 0.36),   // kırmızı
        Color(red: 0.96, green: 0.53, blue: 0.19),   // turuncu
        Color(red: 0.28, green: 0.64, blue: 0.97),   // mavi
        Color(red: 0.62, green: 0.42, blue: 0.95),   // mor
        Color(red: 0.22, green: 0.72, blue: 0.51),   // yeşil
        Color(red: 0.91, green: 0.42, blue: 0.72),   // pembe
        Color(red: 0.35, green: 0.73, blue: 0.78),   // camgöbeği
    ]
    static func color(for name: String) -> Color {
        var h: UInt64 = 5381
        for b in name.utf8 { h = (h &* 33) &+ UInt64(b) }
        return colors[Int(h % UInt64(colors.count))]
    }
}

// MARK: - TwigToggle

/// Keeby kapsül toggle: 44×26, beyaz topuz, açıkken turuncu dolgu.
/// Görsel katman özel; erişilebilirlik gerçek Toggle üzerinden.
struct TwigToggle: View {
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? Theme.accent : Color(red: 0.227, green: 0.227, blue: 0.235))
                .frame(width: 44, height: 26)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle("", isOn: $isOn).labelsHidden() }
    }
}

// MARK: - PillBadge

/// Koyu kapsül değer rozeti (Keeby "100%" / "⌘K").
struct PillBadge: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Theme.mono(12, .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - BorderedPillButton

/// Keeby "Preview" butonu: kapsül, 1px açık kontur, hover'da hafif dolgu.
struct BorderedPillButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(hovered ? Color.white.opacity(0.08) : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - SettingsRow

/// Kart içi ayar satırı: solda başlık (+ opsiyonel alt metin), sağda kontrol,
/// altta hairline (karttaki son satır hariç).
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var showsHairline: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, subtitle == nil ? 15 : 11)
            .frame(minHeight: 52)
            if showsHairline {
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 16)
            }
        }
    }
}
```

- [ ] **Step 3: Verify + commit**

Run: `swift build && swift test` — clean/green. (Controls not yet referenced; unused-warning yok, sadece derleme.)

```bash
git add Sources/WorktreeGUI/Theme.swift Sources/WorktreeGUI/Controls.swift
git commit -m "feat: Keeby dark token set + custom controls (FloatingPanel, IconTile, TwigToggle, PillBadge, SettingsRow)"
```

---

### Task 3: MenuContentView — canvas, floating sidebar cards, detail panel

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: everything from Task 2. Keeps: `handleKey`, `selectIndex`, `cycle`, `groupedRepos`, `reorderGesture`, `RepoDragHandle`, `OptionalShortcut`, all `state.*` calls, all `.contextMenu` blocks, `confirmingRemovalPath` flow — logic untouched, only visual composition changes.
- Produces: nothing new for other tasks.

- [ ] **Step 1: Root layout — canvas + floating panels + forced dark**

Replace the `body` (lines 29–56) composition: outer `HStack(spacing: 10)` inside `.padding(10)`, canvas background, dark scheme. Keep all modifiers (`focusable`, `onKeyPress`, `onAppear`, `onChange`) as they are.

```swift
var body: some View {
    HStack(spacing: 10) {
        if !state.sidebarCollapsed {
            sidebar
                .frame(width: 190)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        FloatingPanel { detail.id(pane).transition(paneTransition) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(10)
    .frame(width: 560, height: 520)
    .background(Theme.canvas)
    .preferredColorScheme(.dark)
    .focusable()
    .focused($navFocused)
    .focusEffectDisabled()
    .onKeyPress(action: handleKey)
    .onAppear { state.refresh(); navFocused = true }
    .onChange(of: pane) { _, new in if new != .newWorktree { navFocused = true } }
    .onChange(of: state.repos.count) { _, _ in
        if selectedRepoPath == nil { selectedRepoPath = state.repos.first?.path }
    }
}
```

Note: old `Divider()` between sidebar and detail is removed; the 10 pt canvas gap replaces it. `detail`'s internal `ZStack`/`clipped()` wrapper folds into the `FloatingPanel` (panel already clips).

- [ ] **Step 2: Sidebar — two stacked floating cards**

Replace `sidebar` (lines 113–155): a `VStack(spacing: 10)` of (1) repo card, (2) utility card. Wordmark satırı repo kartının üstünde kalır.

```swift
private var sidebar: some View {
    VStack(spacing: 10) {
        FloatingPanel {
            VStack(spacing: 0) {
                TwigWordmark(size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(groupedRepos, id: \.group) { section in
                            Text(section.group)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                            ForEach(Array(section.repos.enumerated()), id: \.element.repo.id) { pos, entry in
                                repoRowView(repo: entry.repo, globalIndex: entry.index,
                                            group: section.group, posInGroup: pos,
                                            groupCount: section.repos.count)
                            }
                        }
                    }
                    .padding(.horizontal, 8).padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        FloatingPanel {
            VStack(spacing: 0) {
                utilityRow(symbol: "folder.badge.plus", tile: Color(red: 0.28, green: 0.64, blue: 0.97),
                           label: state.t(.addRepo)) { state.addReposViaPanel() }
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 48)
                utilityRow(symbol: "gearshape.fill", tile: Color(white: 0.45),
                           label: state.t(.settings), active: pane == .settings, shortcut: ",") {
                    withAnimation(selectAnim) { pane = .settings }
                }
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 48)
                utilityRow(symbol: "power", tile: Color(red: 0.94, green: 0.31, blue: 0.36),
                           label: state.t(.quit), shortcut: "q") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 6)
        }
    }
}
```

`utilityRow` replaces `railButton` (delete `railButton`, keep `OptionalShortcut`):

```swift
private func utilityRow(symbol: String, tile: Color, label: String,
                        active: Bool = false, shortcut: KeyEquivalent? = nil,
                        action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 10) {
            IconTile(systemName: symbol, color: tile, side: 26)
            Text(label).font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(active ? Theme.rowSelected : .clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 6)
    .help(label)
    .accessibilityLabel(label)
    .modifier(OptionalShortcut(key: shortcut))
}
```

- [ ] **Step 3: Repo row — icon tile + Keeby selection**

In `repoRowView` (lines 160–207): replace `Label(repo.name, systemImage: "shippingbox").font(.body)` with tile + text; replace selection/hover background; keep grip, gestures, `.help`, `.contextMenu` exactly. `repoRowHeight` (line 19) becomes `38`.

```swift
RepoDragHandle()
    .opacity(isHovered || isDragging ? 1 : 0)
    // ... (grip unchanged)
IconTile(systemName: "shippingbox.fill",
         color: TilePalette.color(for: repo.name), side: 26)
Text(repo.name).font(.system(size: 13, weight: .medium))
Spacer(minLength: 0)
```

Background/foreground changes: selected fill `Theme.rowSelected` (radius 9 continuous), hover `Theme.rowHover`, `foregroundStyle` sabit `.primary` (koyu temada beyaz zaten — `.white` özel durumu kalkar).

- [ ] **Step 4: Detail header + worktree rows + empty states**

`repoDetail` (lines 260–318):
- Header: `SidebarToggle` kalır; `JigMark`-when-collapsed yerine her zaman `IconTile(color: TilePalette.color(for: repo.name), side: 30) { Image(systemName: "shippingbox.fill") }` + `Text(repo.name).font(.system(size: 17, weight: .bold))` (Keeby "Sound" başlığı). Refresh butonu kalır (`.buttonStyle(.plain)`, secondary). "New" butonu turuncu kapsüle döner:

```swift
Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
    Label(state.t(.new), systemImage: "plus")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Theme.accent, in: Capsule())
}
.buttonStyle(.plain)
.help(state.t(.newWorktreeHelp))
.keyboardShortcut("n")
```

- İki `Divider()` → `Rectangle().fill(Theme.hairline).frame(height: 1)`.
- Worktree listesi: `LazyVStack(spacing: 0)`, satır aralarına hairline (`padding(.leading, 16)`); `worktreeRow`'daki hover arka planı `Theme.rowHover` (radius 0 — satırlar kart içinde düz), padding `.horizontal, 16`/`.vertical, 12`. Satır içeriği/aksiyonları/context menu aynen.
- `emptyWorktrees` + `emptyState`: `JigMark`→`TwigMark` zaten Task 1'de değişti; renk `Theme.accent`.

- [ ] **Step 5: Verify + commit**

Run: `swift build && swift test` — clean/green.
Run: `swift run WorktreeGUI` — popover: siyah kanvas, 3 yüzen kart (repo, utility, detay), turuncu New kapsülü, karo ikonlu satırlar. Klavye: 1-9, ⌘N/R/,/Q, ok tuşları, drag-reorder çalışıyor.

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "feat: Keeby layout — canvas + floating sidebar cards + detail panel, icon-tile rows"
```

---

### Task 4: NewWorktreeView — dark form cards

**Files:**
- Modify: `Sources/WorktreeGUI/Views/NewWorktreeView.swift`

**Interfaces:**
- Consumes: `FloatingPanel` değil (form zaten detay paneli içinde) — `Theme.*`, `SettingsRow`, `PillBadge`, `BorderedPillButton`, `IconTile`, `darkField` (aşağıda, bu dosyada private).
- Produces: nothing.

- [ ] **Step 1: Header + section cards**

- Header: `SidebarToggle` + `IconTile(systemName: "plus", color: Theme.accent, side: 30)` + title/repo-name stack (collapsed `TwigMark` satırı kalkar — ikon karo her zaman var).
- Mode picker: segmented `Picker` kalır ama satır olarak bir karta girer. Form gövdesi: `Theme.sectionLabel(...)` başlıkları kartların DIŞINDA, alanlar kart (iç `VStack` + hairline) içinde. Kart = `RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))` — panel içinde ikinci seviye yüzey.
- Text field'lar: `.textFieldStyle(.plain)` + koyu alan kroması:

```swift
private func darkField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
}
```

- Branch `Picker`'ları `.pickerStyle(.menu)` + `.buttonStyle(.plain)` görünümüyle satır sağına yerleşir (`SettingsRow(title:)` trailing'i).
- Log alanı: `Color.white.opacity(0.05)` dolgu, `Theme.hairline` kontur (native `textBackgroundColor`/`separatorColor` kalkar).
- Butonlar: Cancel → `BorderedPillButton(state.t(.cancel))`, Create → turuncu kapsül (Task 3'teki New kapsülüyle aynı stil), `.disabled` durumunda `.opacity(0.4)`. Close → turuncu kapsül. `keyboardShortcut(.cancelAction)` atamaları kalır — kapsüller `Button` olduğu için çalışır.

- [ ] **Step 2: Verify + commit**

Run: `swift build && swift test`; `swift run WorktreeGUI` → New Worktree aç: section başlıkları kart dışı gri, alanlar koyu, Create turuncu kapsül, disable durumu görünür; oluşturma akışı log gösteriyor.

```bash
git add Sources/WorktreeGUI/Views/NewWorktreeView.swift
git commit -m "feat: Keeby dark form — New Worktree pane"
```

---

### Task 5: SettingsView — label-outside-card groups, SettingsRow, custom controls

**Files:**
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `Theme.sectionLabel`, `SettingsRow`, `IconTile`, `PillBadge`, `BorderedPillButton`, `TilePalette`. (`TwigToggle` şu an boolean ayar yok — kontrol seti hazır, kullanılacak boolean eklenince girer; bu görevde kullanılmıyor.)
- Produces: nothing.

- [ ] **Step 1: Replace grouped `Form` with card groups**

`Form { ... }.formStyle(.grouped)` (lines 21–137) yerine `ScrollView` + `VStack(alignment: .leading, spacing: 8)`; her grup: `Theme.sectionLabel(...)` + kart (`VStack(spacing: 0)` içinde `SettingsRow`'lar, `RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04))` zemin). Footer caption'ları kart altına `.font(.system(size: 11.5)) .foregroundStyle(.tertiary)` satırı olarak.

Eşleme (mevcut Section → yeni):
- Language: `SettingsRow(title: state.t(.languageTitle), showsHairline: false)` trailing segmented `Picker` (native, dark'ta zaten uyumlu).
- Repo sources: her kaynak bir `SettingsRow` benzeri özel satır (mono yol + `PillBadge(kind)` + remove butonu `minus.circle.fill` secondary/danger). Kart altında `BorderedPillButton(state.t(.addFromFinder), systemImage: "folder.badge.plus")`.
- Scan depth: `SettingsRow` trailing segmented `Picker` (1...5).
- Terminal / Editor: tek kartta iki `SettingsRow`, trailing `.menu` Picker (`labelsHidden`).
- Package managers: repo başına `SettingsRow(title: repo.name)` — solda `IconTile(systemName: "shippingbox.fill", color: TilePalette.color(for: repo.name), side: 24)` (SettingsRow'a girmek için title yerine custom leading gerekiyorsa satırı elle kur: `HStack { IconTile; Text; Spacer; Picker }` + hairline).
- Startup command: `darkField` benzeri koyu TextField satırı (NewWorktreeView'daki kromayı bu dosyada da private helper olarak tekrar et ya da `Controls.swift`'e `DarkTextField(placeholder:text:onSubmit:)` olarak taşı — taşımayı tercih et, iki dosya kullanıyor). Config yolu satırı: `Theme.mono(11)` tertiary, `textSelection(.enabled)` kalır.
- Header (lines 144–159): `SidebarToggle` + `IconTile(systemName: "gearshape.fill", color: Color(white: 0.45), side: 30)` + `Text(state.t(.settingsTitle)).font(.system(size: 17, weight: .bold))`.

Tüm binding'ler (`depthBinding`, `appBinding`, `pmBinding`, `options`) aynen kalır.

- [ ] **Step 2: Verify + commit**

Run: `swift build && swift test`; `swift run WorktreeGUI` → Settings: gri başlıklar kart dışında, satırlar hairline'lı, picker'lar çalışıyor, kaynak ekleme/silme çalışıyor, startup command kaydediyor (onSubmit).

```bash
git add -A
git commit -m "feat: Keeby settings — label-outside-card groups with SettingsRow"
```

---

### Task 6: Visual QA against reference + final polish

**Files:**
- Modify: as findings dictate (Views/, Theme.swift, Controls.swift)

- [ ] **Step 1: Build app + screenshot**

Run: `./scripts/build-app.sh` then launch, open popover, capture (memory: `worktree-gui-screenshot-howto.md` — synthetic input dismisses the popover; follow the howto).

- [ ] **Step 2: Compare to reference screenshots — checklist**

- Panel radius/gaps: kartlar 14pt, aralar 10pt siyah, dış kenar 10pt.
- Section başlıkları kart DIŞINDA, gri semibold.
- Kart içi hairline'lar leading-inset, son satırda yok.
- İkon karoları: gradient, beyaz sembol, 26–30pt.
- Turuncu kapsül butonlar, `BorderedPillButton` konturu okunuyor.
- Popover kenarında beyaz sızıntı yok (canvas edge-to-edge; gerekirse `.ignoresSafeArea()`).
- Menubar'da twig glyph net (2× template).
- A11y: VoiceOver ile Settings/Quit satırları etiketli; toggle yok ama `TwigToggle` temsili doğru.

- [ ] **Step 3: Fix findings, re-verify, commit**

Run: `swift build && swift test` — green.

```bash
git add -A
git commit -m "polish: Keeby restyle QA fixes vs reference"
```

---

## Self-Review Notes

- Spec §1 Branding → Task 1. §2 Theme/Controls → Task 2. §3 Layout (sidebar/detail/New/Settings) → Tasks 3–5. §5 Verification → her task + Task 6.
- `TwigToggle` bu planda hiçbir view'da bağlanmıyor (uygulamada boolean ayar yok) — spec kontrol setini tanımlıyor, kullanım gelecek ayarlarla gelir. Bilinçli.
- Tip tutarlılığı: `IconTile(systemName:color:side:)`, `SettingsRow(title:subtitle:showsHairline:trailing:)`, `TilePalette.color(for:)` — Tasks 3–5 bu imzaları birebir kullanıyor.
