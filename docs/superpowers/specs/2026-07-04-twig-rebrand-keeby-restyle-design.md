# Twig Rebrand + Keeby-Style Dark Restyle — Design

Date: 2026-07-04
Status: Approved (user, in-session)
Supersedes visual direction of: `2026-06-30-native-consistency-restyle-design.md` (Apple-native direction is replaced by a custom dark design language; behavior/architecture decisions in that spec remain).

## Goal

1. **Rebrand**: app display name `Jig` → **`Twig`**, with a new logo (organic twig glyph).
2. **Restyle**: the entire popover adopts the Keeby design language (reference: https://getkeeby.com and the two user-provided screenshots) — dark-only, floating rounded panels on a black canvas, colorful gradient icon tiles, gray section labels *outside* cards, hairline-separated rows *inside* cards, pixel-faithful custom controls.

## Decisions (user-confirmed)

| Question | Decision |
|---|---|
| New name | **Twig** (simple, one syllable, branch metaphor) |
| Logo | Organic twig glyph: diagonal stem + two round-tipped offshoots. Path-drawn, tints with foreground style |
| Restyle scope | **Entire popover** (repo list, repo detail, New Worktree, Settings) |
| Appearance | **Dark only** (`.preferredColorScheme(.dark)` at root) |
| Brand/accent color | **Orange #FF6A1A stays** — becomes the control accent (toggles, sliders, prominent buttons) |
| Implementation approach | **Pixel-faithful custom controls** (custom toggle, pill badges, bordered buttons, icon tiles — not tinted native controls) |
| Section separation | Per screenshot 2: gray semibold section labels between cards; rows within a card separated by faint hairlines |

## Non-goals

- No target/module renames: `WorktreeGUI` and `WorktreeCore` targets stay.
- Config path stays `~/.config/worktree-gui/config.json`.
- No behavior changes: keyboard shortcuts (⌘N/R/,/Q, Esc, 1-9, Tab/arrows), drag-to-reorder, context menus, hover row actions, creation pipeline all unchanged.
- No light theme.
- `WorktreeCore` untouched.

## 1. Branding

### Files
- `Sources/WorktreeGUI/Brand/JigMark.swift` → `Sources/WorktreeGUI/Brand/TwigMark.swift`
  - `JigMark` → `TwigMark`: a `Path`-drawn glyph (no letterforms). Geometry: one diagonal stem from lower-left to upper-right (rounded caps, weight ~14% of side), two offshoots leaving the stem at ~1/3 and ~2/3 of its length on alternating sides, each ending in a small circular bud. Must read clearly at 18 px (menubar) and scale to 512 px (app icon).
  - `JigWordmark` → `TwigWordmark`: twig glyph + "Twig" text (rounded, heavy, tight tracking).
  - `JigGlyph.menuBarImage` → `TwigGlyph.menuBarImage`: unchanged mechanism (ImageRenderer → template NSImage).
- All call sites updated (`WorktreeGUIApp.swift`, `MenuContentView.swift`, `NewWorktreeView.swift`, `SettingsView.swift`, `Theme.swift` doc comments).
- `scripts/build-app.sh`: `APP_DISPLAY="Twig"`.
- `scripts/make-icon.swift`: regenerate app icon — orange gradient (top-lighter → #FF6A1A) rounded-square tile, white twig glyph, matching the Keeby icon-tile look.
- Accessibility label "Jig" → "Twig". Any L10n strings mentioning Jig (e.g. tagline) reworded for Twig.
- `Brand.signalOrange` (#FF6A1A) stays, but its doc comment changes: no longer "logo only" — it is now the app-wide control accent.

## 2. Theme — Keeby dark token set

`Theme.swift` becomes an owned design system again (reversing the "thin semantic layer" doctrine — that doctrine is explicitly superseded). Root gets `.preferredColorScheme(.dark)`.

Tokens (names indicative):

- `Theme.canvas` — near-black window base (`#0A0A0A`), the "gap" color between floating panels.
- `Theme.panel` — floating card fill (`#1C1C1E` family), corner radius **14**, continuous.
- `Theme.panelStroke` — optional 1 px inner border, white ~4%, for edge definition.
- `Theme.hairline` — row separator inside cards, white 6–8%, inset from leading text edge.
- `Theme.textPrimary` / `textSecondary` / `textTertiary` — white, ~55% white, ~35% white.
- `Theme.sectionLabel` — gray semibold ~13 pt, used *between/outside* cards (Keeby "Feel"/"Tone").
- `Theme.accent` — `Brand.signalOrange`.
- Existing `dotClean`/`dotDirty`/`danger`/`mono()` stay.

### Custom controls (new, in a `Controls/` group or extended Theme.swift)

- **`TwigToggle`** — Keeby-style capsule toggle: track ~44×26, white knob, orange fill when on, gray (`#3A3A3C`) when off; animated; `accessibilityRepresentation` of a real `Toggle` for a11y.
- **`PillBadge`** — dark-gray capsule, mono digits (Keeby "100%" / "⌘K" pills).
- **`BorderedPillButton`** — Keeby "Preview" style: capsule, 1 px light border, subtle fill on hover/press.
- **`IconTile`** — rounded-square (radius ~8, ~28 pt) with vertical gradient fill and white SF Symbol / glyph; color parameterized. Used in sidebar rows and pane headers.
- **`SettingsRow`** — title (+ optional subtitle in secondary) left, control right, min height ~52, hairline below except last-in-card.
- **`FloatingPanel`** — container: `Theme.panel` fill, radius 14, clips content.

## 3. Layout

Popover stays 540×500-ish (may widen slightly if panels need breathing room; keep ≤ 640×540). Canvas background, ~10 pt gaps between panels, ~10 pt outer margin.

### Sidebar (left, width ~190)
Two stacked floating cards, gap between:
1. **Repo card** — scrollable repo list. Each row: `IconTile` (per-repo deterministic color, existing hash; symbol `shippingbox` or first letter) + repo name. Group names render as `sectionLabel` rows inside the card top-padding style (small gray label above its rows). Selected row: lighter fill (`#2C2C2E`), like Keeby's selected "General". Hover: faint fill. Drag-reorder grip behavior unchanged.
2. **Utility card** (bottom, fixed) — rows like Keeby About/Close: **Settings** (gray gear tile) and **Quit** (red power tile). "Add repo" moves to a row here or a header + button in repo card — implementer picks whichever reads cleaner with the reference; must remain one click.

### Detail (right, flexible)
One floating panel:
- **Header**: `IconTile` + pane title (repo name / "New Worktree" / "Settings"), matching Keeby's header row with its icon. Refresh + New actions on the right (New = orange prominent capsule).
- **Repo pane**: worktree rows inside the panel, hairline-separated: status dot, branch name, folder (mono, tertiary), hover actions (editor/terminal/finder/trash) unchanged. Footer line (count + path) at panel bottom in tertiary.
- **New Worktree pane**: form fields grouped into cards with `sectionLabel` headers (e.g. "Branch", "Setup"); text fields restyled dark (custom field chrome, no native bezel).
- **Settings pane**: existing sections become label-outside-card groups with `SettingsRow`s and custom controls (`TwigToggle` for booleans, `PillBadge` for values, pickers restyled dark).

Sidebar collapse (`⌘`-toggle) keeps working; collapsed state hides the left column, detail panel expands.

## 4. Behavior — unchanged

All of: key handling in `MenuContentView.handleKey`, 1-9 selection, reorder `DragGesture`, context menus, hover-reveal row actions, removal confirm flow, `AppState` API, L10n mechanism. Visual layer only.

## 5. Verification

- `swift build` clean; `swift test` still green (Core untouched).
- Visual: build app, launch, screenshot popover (existing screenshot howto), compare against the two reference screenshots for: panel radii/gaps, section label placement, hairlines, toggle shape, icon tiles, header composition.
- A11y spot-check: custom toggle exposes on/off state; icon tiles decorative (hidden) where labels exist.

## Risks

- Custom controls lose free a11y/behavior → mitigated via `accessibilityRepresentation` and keeping focus/keyboard paths on real `Button`s.
- `ImageRenderer` glyph rendering: new Path glyph must be re-checked at 2× for menubar crispness.
- Popover on black canvas: popover chrome has its own corner radius/arrow; canvas must fill edge-to-edge (`ignoresSafeArea`, background on outermost frame) so no white fringes.
