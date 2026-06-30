# Jig — native consistency restyle

Date: 2026-06-30
Status: approved (design), implementing
Supersedes: `2026-06-30-openusage-style-restyle-design.md` (the OpenUsage flat-dark
restyle that this reverses).

## Context

The OpenUsage-inspired restyle (near-black flat canvas, single high-chroma
`signalOrange` accent, 64pt colored letter-avatar rail, bespoke `LiquidTabs`,
gradient/glass/spine flourishes) read as "vibe-coded" — generic dark-dashboard,
not a production Mac app. Root cause is **systemic inconsistency**, not any one
token: five corner radii with no scale, ad-hoc font sizes, custom controls next
to raw AppKit controls, decorative SF Mono, hashed-random avatar colors (4 of the
user's 5 repos collide on the initial "E"), and a flat black surface that floats
over the desktop like a web window instead of a Mac popover.

Direction (user-approved): **Apple-native menubar utility.** Stop owning a brand
visual language; sit on the platform's own system (semantic fonts, semantic
colors, system accent, system materials). The brand survives only as the JigMark
logo + menubar icon.

Top priority (user, verbatim): consistency in the fundamentals — **color,
buttons, typography, the "section" concept.**

## Locked decisions

1. **Direction:** Apple-native utility. Lean into the platform; remove the owned
   dark-dashboard system.
2. **Color:** system accent (`.tint`/`.borderedProminent` default) for all
   selection/emphasis/primary actions. `Brand.signalOrange` removed from every
   control, fill, selection spine, and gradient. Orange remains ONLY in the
   `JigMark` logo and the menubar icon. All colors become semantic (HIG 9.3/9.4).
3. **Sidebar:** native source list (`List(selection:)` + `.listStyle(.sidebar)`),
   repo name + group visible per row, system-accent selection highlight. The 64pt
   avatar rail and per-repo hashed colors are removed (HIG 4.2).

## Derived decisions (native idiom + the consistency priority)

- **Appearance:** follow system — full Light + Dark via semantic colors. The
  hardcoded near-black `Theme.canvas` is removed. (User flagged as a cheap veto
  point; default is both modes.)
- **Materials:** `.listStyle(.sidebar)` gives the sidebar automatic vibrancy;
  detail/Settings sit on `windowBackgroundColor`. Respect Reduce Transparency
  (HIG 9.5/11.4) — the system list/material paths already do.
- **Typography:** one semantic type ramp (HIG 9.1). No hardcoded point sizes for
  chrome. SF Mono is reserved, not decorative (rule below).
- **Sections:** Settings becomes a native grouped `Form` (`Section` +
  `.formStyle(.grouped)`) — the System-Settings look for free, with consistent
  headers/insets/light-dark. This is the single "section" pattern.
- **Controls:** `LiquidTabs` is replaced by `.pickerStyle(.segmented)` everywhere
  (branch mode, language, scan depth). No bespoke controls.
- **Flourishes removed:** `AccentSpine`, accent gradient, Liquid Glass capsule,
  press-scale, row-action slide-offset. Motion stays minimal and Reduce-Motion
  aware.

## Type ramp

| Role | Style |
|---|---|
| Pane title (repo name, "New Worktree", "Settings") | `.title3` semibold |
| Section header | `.headline` |
| Row primary (branch name, repo name) | `.body` |
| Row secondary (group, caption, hint) | `.subheadline` or `.caption`, `.secondary` |
| Count / footer | `.caption`, `.secondary` |

**SF Mono rule:** only read-only filesystem paths (worktree folder, repo path,
config path) and terminal log output. Every input field and every label is SF Pro
— including the new-branch field (it currently uses mono; switch to default).

## Button / control families

- Primary: `.borderedProminent` (Create, New). Removes `AccentPill` + gradient.
- Secondary: `.bordered` (Cancel, Add from Finder). Removes `GhostPill`.
- Inline row icons: `.borderless`. Removes `RowActionButton`/`RailButton` custom
  fills in favor of `.borderless` + native hover, or a thin shared style if
  needed for the hover affordance.
- Destructive: `role: .destructive` (system red), e.g. worktree delete.

## Spacing

HIG 9.6: 20pt window margins, 8pt spacing between related controls, 20pt between
groups. Replace ad-hoc `14/18/12/9` paddings with this grid. Kill the 6/7/10
radius sprawl — native controls own their radius; any remaining custom surface
uses one token.

## Per-file task breakdown

### Task 1 — `Theme.swift` + `Brand`/`JigMark` (foundation, do first, alone)

This file is the shared contract every view consumes. After this task the views
only *consume* Theme; they must not add to it.

- Remove from `Theme`: `accent` (= signalOrange), `canvas`, `surfaceRaised`,
  `hover`, `selected`, `railWidth`, `avatarPalette`, `avatarColor(for:)`, the
  `rControl`/`rRow` radius pair (replace with a single `rCard`/`rControl` token
  only if still needed by a custom surface), the `Brand.tint*`/`accentGradient`/
  `spine` tokens.
- Keep/rename: `mono(_:_:)` (paths/log only), `dotClean`/`dotDirty` (semantic
  green/red), `danger` (→ prefer `role: .destructive` at call sites; keep token
  only if a non-button red is needed), `InstalledApps`, `SidebarToggle`.
- `Brand` shrinks to just the logo color: keep `signalOrange` (+ the
  logo-only gradient if `JigMark` needs it) and nothing control-facing.
- Remove button styles `AccentPill`, `GhostPill`; remove `LiquidTabs` +
  `GlassIndicator`; remove `AccentSpine`. Call sites move to native
  `.borderedProminent` / `.bordered` / `.borderless` / `.pickerStyle(.segmented)`.
- Update the file header comment to describe the native direction (currently
  describes the OpenUsage flat-canvas philosophy).
- Net: `Theme` becomes a thin semantic-token + helper file, not a parallel design
  system. Report the final public surface (what remains) so the view tasks bind
  to it exactly.

### Task 2 — `MenuContentView.swift` (sidebar + detail)

- Sidebar: replace the 64pt `sidebar`/`repoRow` avatar rail with a
  `List(selection:)` + `.listStyle(.sidebar)`. Each row: leading SF Symbol
  (one consistent symbol, e.g. `folder`/`shippingbox`) + repo name (`.body`) +
  group (`.subheadline`/`.caption` secondary). Selection drives `selectedRepoPath`
  via the List selection binding; selection highlight is system-native (drop
  `AccentSpine`). Preserve the 1-9 keyboard shortcuts and the footer rail buttons
  (add repo / settings / quit) as `.borderless`.
- Detail header: repo name `.title3` semibold + group `.subheadline` secondary;
  trailing refresh (`.borderless`) + New (`.borderedProminent`). Keep `JigMark`
  in brand orange wherever it appears (collapsed header, empty state) — it is the
  logo, the one allowed brand-orange use.
- Worktree rows: clean/dirty dot (`Theme.dotClean`/`dotDirty`), branch `.body`,
  folder path `.caption` mono secondary. Hover-revealed `.borderless` action
  icons (editor/terminal/finder/trash, trash `role: .destructive`) PLUS a
  right-click `.contextMenu` mirroring them (HIG 6.2). Remove the slide-offset
  animation; keep a simple opacity reveal, Reduce-Motion aware.
- Footer: count `.caption` secondary + repo path `.caption` mono secondary.
- Surfaces: remove `Theme.canvas`; let the popover/material + semantic
  backgrounds show. Apply the 20/8/20 spacing grid.

### Task 3 — `SettingsView.swift`

- Convert the whole pane to a `Form { Section { … } }` with
  `.formStyle(.grouped)`. Drop the hand-rolled `section(_:_:content:)` card and
  `Theme.surfaceRaised`. Each current section becomes a `Section` with a header
  (and footer caption where the current caption adds value).
- Language + scan-depth: `.pickerStyle(.segmented)` (replacing `LiquidTabs`).
- Terminal/editor/package-manager pickers: native `.menu` pickers inside Form
  rows (`LabeledContent`/`Picker` with a visible label rather than `labelsHidden`).
- Source rows / package-manager rows: native Form rows; remove custom capsule
  chip styling in favor of a plain secondary label or `.badge`. Remove button
  `GhostPill` → `.bordered`/`.borderless`.
- Config-path hint: `.caption` mono secondary, `textSelection(.enabled)`.

### Task 4 — `NewWorktreeView.swift`

- Branch-mode switch: `.pickerStyle(.segmented)` (replacing `LiquidTabs`).
- Text fields (`newBranch`, `taskName`): default SF Pro font (remove
  `Theme.mono(12)`); keep `.roundedBorder`. Labels via the `labeled` helper →
  `.subheadline`/`.caption` secondary, or switch to `LabeledContent`.
- Buttons: Cancel `.bordered`, Create `.borderedProminent` (remove `AccentPill`/
  `GhostPill`). Keep the disabled/opacity gating.
- Log box: keep mono (terminal output) but on a semantic background
  (`Color(nsColor: .textBackgroundColor)` or a `GroupBox`), not `Theme.hover`.
- Apply the 20/8/20 spacing grid.

## Scope / out of scope

- This is a visual + structural consistency pass. **No behavior changes.**
- **`WorktreeCore` is untouched** — no logic, no model, no test changes. All
  existing `WorktreeCoreTests` stay green by construction.
- No new features: no dev-server tracking, ahead/behind, drag-reorder, Spotlight/
  Share/App Intents (those HIG items target full document apps, not this
  menubar utility).
- Window size: keep ~560×580; if the ~200pt source list + detail feels cramped,
  widen modestly (≤640) during the build pass. Not resizable (it is a popover —
  HIG 10.3, sized to content).
- Menu-bar/commands (HIG §1) stay out — Jig is an `LSUIElement` accessory app by
  design; no main menu bar.

## Testing / verification

- GUI target has no test target (repo convention) — verify visually by building
  `WorktreeGUI.app` and inspecting the popover in both Light and Dark.
- `swift build` must stay clean; `swift test` (Core only) must stay green
  (Core is untouched).
- Verification uses the `/run` + screenshot flow (see memory:
  worktree-gui-screenshot-howto).

## Implementation orchestration

- **Phase 1:** Task 1 (Theme foundation) — one focused subagent, alone. Build.
  Main thread reads the resulting Theme public surface and locks the contract.
- **Phase 2:** Tasks 2/3/4 — three parallel subagents (distinct files, no shared
  edits; they consume the locked Theme, never modify it). Each builds its own
  file's compile sanity where possible.
- **Phase 3:** Main thread `swift build`, fix integration gaps, screenshot Light
  + Dark, iterate.
