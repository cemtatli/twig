# Jig — OpenUsage-inspired visual restyle

Date: 2026-06-30
Status: approved (design), pending implementation plan

## Context

Jig's current UI follows an Apple-native direction: `NSVisualEffectView` vibrancy
surfaces, system-semantic text colors, a 200pt named source-list sidebar
(`Sources/WorktreeGUI/Views/MenuContentView.swift`). The user wants the visual
language of a third-party reference app, **OpenUsage** (a menubar usage-tracker
app), applied to Jig: a near-black flat canvas, a narrow icon-only nav rail,
tight typographic contrast, thin stat-style rows, and colored status dots.

Scope was narrowed through discussion:
- **Structure**: the repo sidebar becomes a narrow icon rail (not just
  reskinned as a named list) — repo names move to tooltips, selection still
  works via 1-9 keyboard shortcuts.
- **Status dots**: only git dirty/clean is in scope. Dev-server-running is
  explicitly out of scope — Jig launches the dev server as a detached process
  in the user's terminal app and does not track its PID; adding that tracking
  is a separate, larger change.
- **Settings pane**: also restyled to match, since the user supplied a second
  OpenUsage reference screenshot of its settings screen.
- Out of scope: window size change, new features beyond status dots, dev
  server tracking, ahead/behind-remote tracking.

## 1. Theme tokens (`Sources/WorktreeGUI/Theme.swift`)

- Replace `VisualEffect`/vibrancy as the sidebar/detail surface with a solid
  near-black canvas color (`Theme.canvas`, roughly `Color(white: 0.05)` in
  dark mode). This is a deliberate departure from the current "native macOS
  vibrancy" philosophy documented in this file's header comment — the header
  comment gets updated to reflect the new direction.
- Add `Theme.railWidth: CGFloat` (~64pt) replacing the hardcoded `200` sidebar
  width in `MenuContentView`.
- Add `Theme.dotClean` (`Color(nsColor: .systemGreen)`) and `Theme.dotDirty`
  (`Color(nsColor: .systemRed)`) — kept distinct from `Brand.signalOrange`
  (which already means "selected/accent") so a dirty dot doesn't read as a
  selection indicator.
- `reduceTransparency` accessibility path collapses (solid canvas is now the
  only path, vibrancy is gone) — simplifies `sidebarSurface`/`detailSurface`
  in `MenuContentView` to a plain color.

## 2. Sidebar → narrow icon rail (`MenuContentView.swift`)

- `sidebar` computed view: width changes from `200` to `Theme.railWidth`.
  `JigWordmark` (text logo) replaced by icon-only `JigMark` at the top — no
  room for text at rail width. The "Depolar" section label is dropped (no
  room; matches OpenUsage's unlabeled rail).
- `repoRow(_:index:)`: drop the `VStack` with repo name/group text. Each row
  becomes a single rounded-square avatar badge:
  - Selected: `Brand.signalOrange` fill, white first-letter glyph, left-edge
    `AccentSpine` (existing component, reused as-is).
  - Unselected: subtle gray fill (`Color.primary.opacity(0.08)`, existing
    token), first-letter glyph in `Theme.textSecondary`.
  - First-letter glyph: `String(repo.name.prefix(1)).uppercased()`.
  - `.help("\(repo.group)/\(repo.name)  ·  \(index + 1)")` is unchanged
    (already provides the tooltip identification the rail now depends on).
- 1-9 keyboard shortcuts (`handleKey`/`selectIndex`) are untouched — they key
  off `state.repos` index, not the row's visual content.
- Bottom rail buttons (add repo / settings / quit) keep their current
  `RailButton` component, just re-centered for the new narrower width.
- Repo count overflow: vertical `ScrollView` (already present) is kept as-is.

## 3. Worktree rows — git dirty/clean status dot

### Data plumbing

- `GitService` (`Sources/WorktreeCore/Git/GitService.swift`) gains:
  ```swift
  func isDirty(worktreePath: String) throws -> Bool {
      let result = try runner.run("git", ["-C", worktreePath, "status", "--porcelain"], cwd: nil)
      guard result.exitCode == 0 else {
          throw GitError.command(args: ["status", "--porcelain"], exitCode: result.exitCode, stderr: result.stderr)
      }
      return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  ```
  Follows the existing `git(_:)` private-helper pattern used by every other
  `GitService` method.
- `Worktree` (`Sources/WorktreeCore/Models/Repo.swift`) gains a stored
  `var isDirty: Bool = false` field. Not part of any persisted config, so no
  `Codable` concerns — it's populated fresh on every refresh.
- `AppState.refresh()` (`Sources/WorktreeGUI/AppState.swift`, around lines
  43-46 where `git.worktrees(repoPath:)` results are filtered): after
  building each repo's worktree list, run `git.isDirty(worktreePath:)` per
  worktree (best-effort — failure leaves `isDirty = false`, non-fatal, same
  tolerance pattern as the existing `fetch` call in the creation pipeline).

### UI

- `worktreeRow` in `MenuContentView.swift`: small filled circle (`Theme.dotClean`
  or `Theme.dotDirty`) placed before the branch icon. No dot shown while
  status is unknown/loading — defaults to clean-colored only after the
  refresh populates it (matches existing `isRefreshing` pattern elsewhere).

## 4. Settings pane restyle (`SettingsView.swift`)

- `section(_:_:content:)` helper: card background changes from
  `Color.primary.opacity(0.04)` + hairline stroke to a solid near-black fill
  (`Theme.canvas` lightened slightly, no stroke) — matches OpenUsage's flat
  card look.
- Language picker and scan-depth picker: replace `.pickerStyle(.segmented)`
  with an extended version of the existing `LiquidTabs` component (already in
  `Theme.swift`) styled as a flat white-filled selected pill on dark
  background, matching the OpenUsage System/Light/Dark control. `LiquidTabs`
  already supports generic `Hashable` selections, so this is a styling
  change to `GlassIndicator`'s pre-macOS-26 fallback path, not a new
  component.
- Source rows / package-manager rows: structurally unchanged (icon + label +
  control), background fill updated to match the new canvas tone.

## 5. Testing

- `WorktreeCoreTests`: new tests for `GitService.isDirty` using the existing
  `FakeProcessRunner` queued-result pattern — one case with empty porcelain
  output (clean), one with non-empty output (dirty), one with a non-zero exit
  code (throws `GitError`).
- No new SwiftUI view tests — the GUI target has no test target per this
  repo's conventions. Visual verification happens by building
  `WorktreeGUI.app` and inspecting the popover directly (the `/run` skill).

## Out of scope / explicitly deferred

- Dev-server-running status dot (needs PID tracking infrastructure that
  doesn't exist yet).
- Ahead/behind-remote tracking.
- Window size/dimensions change.
- Any change to the creation pipeline, placeholder resolution, or config
  schema.
