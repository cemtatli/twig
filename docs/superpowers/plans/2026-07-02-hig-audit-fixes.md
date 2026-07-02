# HIG Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the 12 approved HIG-audit fixes (spec: `docs/superpowers/specs/2026-07-02-hig-audit-fixes-design.md`) to the WorktreeGUI popover — backgrounds, sidebar polish, typography, keyboard shortcuts, accessibility — with zero behavior change.

**Architecture:** All changes are view-layer (SwiftUI, `Sources/WorktreeGUI/`) except four new `L10nKey` string cases in `WorktreeCore/L10n/L10n.swift`. No new state, no new services, no model changes. The uncommitted drag-to-reorder work (Config.repoOrder, AppState.moveRepo, custom sidebar rows) stays as-is and is styled, not replaced.

**Tech Stack:** Swift 5.9 / SwiftUI, macOS 14+, SwiftPM. No dependencies.

## Global Constraints

- **No behavior changes** — visual/interaction only (spec "Scope dışı").
- `WorktreeCore` logic untouched; ONLY string additions to `L10n.swift` allowed (both `en` + `tr` tables, always).
- GUI target has no tests (repo convention). Verification per task = `swift build` clean; Core task additionally `swift test` green. Final task = screenshot verification Light + Dark.
- UI strings bilingual via `state.t(.key)` — never hardcode user-facing text.
- Mono font (`Theme.mono`) ONLY for filesystem paths and terminal log output.
- Code comments match surrounding language (Turkish/English mixed, per file).
- Reduce Motion: every new animation gated on `accessibilityReduceMotion`.
- Window stays 540×500. `Theme.swift` gains no new tokens.

---

### Task 1: L10n keys for status tooltips and reorder menu

**Files:**
- Modify: `Sources/WorktreeCore/L10n/L10n.swift`

**Interfaces:**
- Produces: `L10nKey.statusClean`, `.statusDirty`, `.moveUp`, `.moveDown` — consumed by Tasks 3 and 4 via `state.t(.statusClean)` etc.

- [ ] **Step 1: Add the four keys to `L10nKey`**

In `L10n.swift`, extend the "Repo detail + worktree rows" case group (line ~15):

```swift
    // Repo detail + worktree rows
    case noWorktreesYet, createFirstWorktree, deletePrompt, worktreeWord, branchPlus
    case cancel, finder, delete, noRepositories, loading, pickFolderHint
    case statusClean, statusDirty, moveUp, moveDown
```

- [ ] **Step 2: Add English strings**

In the `.en` table, after the `.pickFolderHint` entry:

```swift
            .statusClean: "No uncommitted changes",
            .statusDirty: "Uncommitted changes",
            .moveUp: "Move Up", .moveDown: "Move Down",
```

- [ ] **Step 3: Add Turkish strings**

In the `.tr` table, after the `.pickFolderHint` entry:

```swift
            .statusClean: "Kaydedilmemiş değişiklik yok",
            .statusDirty: "Kaydedilmemiş değişiklik var",
            .moveUp: "Yukarı Taşı", .moveDown: "Aşağı Taşı",
```

- [ ] **Step 4: Build and run Core tests**

Run: `swift build && swift test`
Expected: build clean, all tests PASS (L10n has no logic change; `CaseIterable` growth is safe).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/L10n/L10n.swift
git commit -m "feat: L10n keys for git status tooltips and reorder menu"
```

---

### Task 2: Popover backgrounds + sidebar polish (findings 1–4)

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: no API — visual only. Later tasks edit other regions of the same file; keep diffs surgical.

- [ ] **Step 1: Root backgrounds (finding 1)**

In `body`, on the outer `HStack(spacing: 0)` — after `.frame(width: 540, height: 500)` — add an opaque semantic base so the popover no longer bleeds the desktop through, and Light/Dark render correctly:

```swift
        .frame(width: 540, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
```

And give the sidebar its source-list feel: in `sidebar`, on the outer `VStack(spacing: 0)` (after the closing brace of the footer `HStack`'s `.padding`), add:

```swift
        .background(.ultraThinMaterial)
```

(Material sits over the opaque window background → subtle tonal difference, deterministic in both modes. The existing `Divider()` between sidebar and detail stays.)

- [ ] **Step 2: Native selection token (finding 4)**

In `repoRowView`, replace the selection fill:

```swift
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Color(nsColor: .selectedContentBackgroundColor))
                      : isHovered ? AnyShapeStyle(Color.primary.opacity(0.08))
                      : AnyShapeStyle(Color.clear))
        )
```

The `.foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))` line stays — white on `selectedContentBackgroundColor` is the native pairing.

- [ ] **Step 3: Grip only on hover (finding 2)**

In `repoRowView`, the `RepoDragHandle()` keeps its frame (no layout shift) but fades in on row hover or while dragging. Replace:

```swift
            RepoDragHandle()
                .highPriorityGesture(reorderGesture(repo: repo, group: group,
                                                    posInGroup: posInGroup, groupCount: groupCount))
```

with:

```swift
            RepoDragHandle()
                .opacity(isHovered || isDragging ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12),
                           value: isHovered || isDragging)
                .highPriorityGesture(reorderGesture(repo: repo, group: group,
                                                    posInGroup: posInGroup, groupCount: groupCount))
```

(`RepoDragHandle` already carries its own `0.4` internal opacity; the row-level `1`/`0` gates visibility.)

- [ ] **Step 4: Source-list group header (finding 3)**

In `sidebar`, restyle the section header:

```swift
                        Text(section.group)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 4)
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "fix: opaque semantic backgrounds, native selection token, hover-only grips"
```

---

### Task 3: Worktree row + error text + status accessibility (findings 5, 6, 8)

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift`

**Interfaces:**
- Consumes: `L10nKey.statusClean` / `.statusDirty` from Task 1.

- [ ] **Step 1: Remove the slide-offset (finding 5)**

In `worktreeRow`, the hover-revealed action cluster currently reads:

```swift
                .opacity(hovered ? 1 : 0)
                .offset(x: reduceMotion ? 0 : (hovered ? 0 : 8))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
```

Delete the `.offset(x:)` line only — opacity reveal stays:

```swift
                .opacity(hovered ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
```

- [ ] **Step 2: Error text becomes SF Pro caption + warning icon (finding 6)**

In `repoDetail`, replace:

```swift
            if let err = state.lastError {
                Text(err).font(Theme.mono(11)).foregroundStyle(Theme.danger).lineLimit(2)
                    .padding(.horizontal, 20).padding(.bottom, 10)
            }
```

with:

```swift
            if let err = state.lastError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(Theme.danger).lineLimit(2)
                    .padding(.horizontal, 20).padding(.bottom, 10)
            }
```

(The mono error under the NewWorktree log box is stderr output — it stays mono, do not touch.)

- [ ] **Step 3: Status dot tooltip + accessibility (finding 8)**

In `worktreeRow`, replace the bare dot:

```swift
            Circle()
                .fill(wt.isDirty ? Theme.dotDirty : Theme.dotClean)
                .frame(width: 6, height: 6)
```

with:

```swift
            Circle()
                .fill(wt.isDirty ? Theme.dotDirty : Theme.dotClean)
                .frame(width: 6, height: 6)
                .help(state.t(wt.isDirty ? .statusDirty : .statusClean))
                .accessibilityLabel(state.t(wt.isDirty ? .statusDirty : .statusClean))
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "fix: opacity-only row reveal, SF Pro error caption, status dot tooltip + a11y"
```

---

### Task 4: Keyboard shortcuts + repo context menu (findings 9, 10, 11)

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift`
- Modify: `Sources/WorktreeGUI/Views/NewWorktreeView.swift`

**Interfaces:**
- Consumes: `L10nKey.moveUp` / `.moveDown` from Task 1; existing `state.moveRepo(path:inGroup:toGroupIndex:)`, `state.openFinder(_:)`.

Shortcuts ride the button key-equivalent system (works even while a text field has focus), with a `handleKey` fallback for ⌘Q/⌘, so they survive a collapsed sidebar.

- [ ] **Step 1: ⌘N on the New button**

In `repoDetail`:

```swift
                Button { withAnimation(selectAnim) { pane = .newWorktree } } label: {
                    Label(state.t(.new), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent).help(state.t(.newWorktreeHelp))
                .keyboardShortcut("n")
```

- [ ] **Step 2: ⌘R on the refresh button**

In `repoDetail`:

```swift
                Button { state.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderless).foregroundStyle(.secondary)
                .help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))
                .keyboardShortcut("r")
```

- [ ] **Step 3: ⌘, and ⌘Q on the rail buttons**

`railButton` takes no shortcut parameter — add an optional one:

```swift
    private func railButton(_ symbol: String, label: String, active: Bool = false,
                            shortcut: KeyEquivalent? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .help(label)
        .accessibilityLabel(label)
        .modifier(OptionalShortcut(key: shortcut))
    }
```

Add the small helper at file scope (bottom of `MenuContentView.swift`, next to `RepoDragHandle`):

```swift
/// `.keyboardShortcut` kabul eden ama nil'de hiçbir şey eklemeyen sarmalayıcı —
/// railButton'ın opsiyonel kısayol parametresi için.
private struct OptionalShortcut: ViewModifier {
    let key: KeyEquivalent?
    func body(content: Content) -> some View {
        if let key { content.keyboardShortcut(key) } else { content }
    }
}
```

Wire the call sites in `sidebar`:

```swift
                railButton("gearshape", label: state.t(.settings), active: pane == .settings,
                           shortcut: ",") {
                    withAnimation(selectAnim) { pane = .settings }
                }
                Spacer()
                railButton("power", label: state.t(.quit), shortcut: "q") {
                    NSApplication.shared.terminate(nil)
                }
```

- [ ] **Step 4: handleKey fallback for collapsed sidebar**

Rail buttons unmount when the sidebar is collapsed, killing their key equivalents. Add a command-modifier branch at the TOP of `handleKey` (before the `pane == .newWorktree` early return):

```swift
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            switch press.characters {
            case "q": NSApplication.shared.terminate(nil); return .handled
            case ",": withAnimation(selectAnim) { pane = .settings }; return .handled
            default: break
            }
        }
        if pane == .newWorktree { return .ignored }
        ...
```

- [ ] **Step 5: Esc closes the New Worktree pane**

In `NewWorktreeView.swift`, both dismiss buttons get the cancel key. Only one renders at a time:

```swift
                    if submitted {
                        Button(state.t(.close)) { onClose() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.cancelAction)
                        Spacer()
                    } else {
                        Button(state.t(.cancel)) { onClose() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
```

- [ ] **Step 6: Repo row context menu (findings 10, 11)**

In `repoRowView`, after `.help(...)`, add:

```swift
        .contextMenu {
            Button(state.t(.moveUp)) {
                withAnimation(selectAnim) {
                    state.moveRepo(path: repo.path, inGroup: group, toGroupIndex: posInGroup - 1)
                }
            }
            .disabled(posInGroup == 0)
            Button(state.t(.moveDown)) {
                withAnimation(selectAnim) {
                    state.moveRepo(path: repo.path, inGroup: group, toGroupIndex: posInGroup + 1)
                }
            }
            .disabled(posInGroup == groupCount - 1)
            Divider()
            Button(state.t(.finder)) { state.openFinder(repo.path) }
        }
```

- [ ] **Step 7: Build**

Run: `swift build`
Expected: clean.

- [ ] **Step 8: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift Sources/WorktreeGUI/Views/NewWorktreeView.swift
git commit -m "feat: keyboard shortcuts (cmd-N/R/,/Q, Esc) + repo row context menu with keyboard reorder"
```

---

### Task 5: Create-button dim + Settings config hint (findings 7, 12)

**Files:**
- Modify: `Sources/WorktreeGUI/Views/NewWorktreeView.swift`
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift`

**Interfaces:**
- Consumes: nothing new.

- [ ] **Step 1: Drop the manual opacity on Create (finding 7)**

In `NewWorktreeView.swift`, the Create button currently ends with:

```swift
                        .buttonStyle(.borderedProminent)
                        .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
                        .opacity(effectiveBranch.isEmpty || taskName.isEmpty ? 0.4 : 1)
```

Delete the `.opacity(...)` line — native `.disabled` dimming is enough:

```swift
                        .buttonStyle(.borderedProminent)
                        .disabled(effectiveBranch.isEmpty || taskName.isEmpty)
```

- [ ] **Step 2: Config hint moves into the last Section footer (finding 12)**

In `SettingsView.swift`, the startup-command Section's footer becomes:

```swift
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.t(.startupCommandCaption))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.t(.editConfigHint))
                            Text(ConfigStore.defaultPath.abbreviatingHome)
                                .font(Theme.mono(11))
                                .textSelection(.enabled)
                        }
                    }
                }
```

Then delete: the `configHint` computed property entirely, and its call site (`configHint` line under `.formStyle(.grouped)` in `body`).

- [ ] **Step 3: Build**

Run: `swift build`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Views/NewWorktreeView.swift Sources/WorktreeGUI/Views/SettingsView.swift
git commit -m "fix: native disabled dim on Create, config hint as Form footer"
```

---

### Task 6: Visual verification — Light + Dark screenshots

**Files:**
- None modified (verification only; fix regressions if found).

**Interfaces:**
- Consumes: the built app from all prior tasks.

- [ ] **Step 1: Build the app bundle**

Run: `./scripts/build-app.sh`
Expected: `OK: built /Users/example/Dev/worktree_gui/WorktreeGUI.app`

- [ ] **Step 2: Dark-mode screenshot**

```bash
pkill -x WorktreeGUI; sleep 1; open WorktreeGUI.app; sleep 2
osascript -e 'tell application "System Events" to tell process "WorktreeGUI" to click menu bar item 1 of menu bar 2' && sleep 0.8 && \
screencapture -x -R1218,36,550,510 /tmp/jig-dark.png
```

(Region assumes the popover at 1223,41 540×500 — re-query with `osascript -e 'tell application "System Events" to tell process "WorktreeGUI" to get {position, size} of window 1'` if the capture misses. Synthetic clicks/keystrokes dismiss the popover — capture in ONE command chain.)

Inspect `/tmp/jig-dark.png`: no desktop/window bleed-through behind the detail pane; sidebar tonally distinct; grips hidden (no hover); group header legible.

- [ ] **Step 3: Light-mode screenshot**

```bash
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' && sleep 1.5 && \
osascript -e 'tell application "System Events" to tell process "WorktreeGUI" to click menu bar item 1 of menu bar 2' && sleep 0.8 && \
screencapture -x -R1218,36,550,510 /tmp/jig-light.png && \
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
```

Inspect `/tmp/jig-light.png`: detail pane LIGHT (this was the bug), text dark/semantic, no bleed-through.

- [ ] **Step 4: Keyboard spot-check (manual, user or interactive)**

With the popover open: ⌘N opens New Worktree, Esc closes it, ⌘R spins refresh, ⌘, opens Settings, ⌘Q quits. Report any failures instead of claiming success.

- [ ] **Step 5: Commit any verification fixes**

If Steps 2–4 exposed regressions, fix minimally and commit:

```bash
git add -A Sources/
git commit -m "fix: visual verification follow-ups"
```
