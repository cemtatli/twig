# OpenUsage-style Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle Jig's menubar UI to a near-black, OpenUsage-inspired visual
language — narrow icon-rail sidebar, git dirty/clean status dots on worktree
rows, and a matching Settings pane — per
`docs/superpowers/specs/2026-06-30-openusage-style-restyle-design.md`.

**Architecture:** Bottom-up. First extend `WorktreeCore` (the tested layer)
with a `GitService.isDirty` git-status check and a `Worktree.isDirty` field.
Then wire that into `AppState.refresh()`. Then restyle the `WorktreeGUI`
layer top-down: shared `Theme` tokens first, then the sidebar rail, then the
worktree-row status dot, then `SettingsView`.

**Tech Stack:** Swift Package Manager, SwiftUI, AppKit interop (`Theme.swift`),
XCTest with the project's `FakeProcessRunner` seam.

## Global Constraints

- macOS 14+, Swift tools version 5.9, no external dependencies.
- Every new call to a system process must go through `ProcessRunner` —
  `GitService` already does this via its private `git(_:)` helper; reuse it.
- All `WorktreeCore` tests use the queued-results `FakeProcessRunner` and
  assert on `fake.calls` / thrown `GitError`. The GUI target (`WorktreeGUI`)
  has no test target — GUI changes are verified by building the app and
  inspecting it manually, not by automated tests.
- UI-facing strings are Turkish; this plan adds no new user-facing strings,
  so no `L10n` changes are needed.
- Build/verify command after every task: `swift build`. Full test suite:
  `swift test`.

---

### Task 1: `GitService.isDirty` + `Worktree.isDirty` field

**Files:**
- Modify: `Sources/WorktreeCore/Models/Repo.swift:14-22` (the `Worktree` struct)
- Modify: `Sources/WorktreeCore/Git/GitService.swift` (add a method after `worktrees(repoPath:)`, which ends around line 46)
- Test: `Tests/WorktreeCoreTests/GitServiceTests.swift`

**Interfaces:**
- Consumes: existing `ProcessRunner` protocol, `GitError.command`, the
  private `git(_:)` helper pattern already in `GitService.swift`.
- Produces: `GitService.isDirty(worktreePath: String) throws -> Bool` and
  `Worktree.isDirty: Bool` (stored property, defaults to `false`) — both
  consumed by Task 2 (`AppState.refresh()`) and Task 5 (status dot UI).

- [ ] **Step 1: Write the failing tests**

Append to `Tests/WorktreeCoreTests/GitServiceTests.swift`, inside the
`GitServiceTests` class (after the existing `testPruneBuildsArgs` test):

```swift
    func testIsDirtyTrueWhenPorcelainNonEmpty() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: " M file.swift\n", stderr: "")]
        XCTAssertTrue(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
        XCTAssertEqual(fake.calls.first?.args, ["-C", "/wt/x", "status", "--porcelain"])
    }

    func testIsDirtyFalseWhenPorcelainEmpty() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "", stderr: "")]
        XCTAssertFalse(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
    }

    func testIsDirtyFalseWhenPorcelainWhitespaceOnly() throws {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 0, stdout: "\n", stderr: "")]
        XCTAssertFalse(try GitService(runner: fake).isDirty(worktreePath: "/wt/x"))
    }

    func testIsDirtyThrowsOnNonZeroExit() {
        let fake = FakeProcessRunner()
        fake.results = [ProcessResult(exitCode: 128, stdout: "", stderr: "fatal: not a git repo")]
        XCTAssertThrowsError(try GitService(runner: fake).isDirty(worktreePath: "/wt/x")) { error in
            XCTAssertEqual(error as? GitError,
                           .command(args: ["-C", "/wt/x", "status", "--porcelain"],
                                    exitCode: 128, stderr: "fatal: not a git repo"))
        }
    }

    func testWorktreeIsDirtyDefaultsFalse() {
        XCTAssertFalse(Worktree(path: "/wt/x", branch: "main").isDirty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter GitServiceTests`
Expected: FAIL — `isDirty` is not a member of `GitService`, and `Worktree`
has no member `isDirty`.

- [ ] **Step 3: Add the `isDirty` field to `Worktree`**

In `Sources/WorktreeCore/Models/Repo.swift`, replace lines 14-22:

```swift
public struct Worktree: Equatable, Identifiable, Hashable {
    public var path: String
    public var branch: String
    public var id: String { path }

    public init(path: String, branch: String) {
        self.path = path; self.branch = branch
    }
}
```

with:

```swift
public struct Worktree: Equatable, Identifiable, Hashable {
    public var path: String
    public var branch: String
    public var isDirty: Bool
    public var id: String { path }

    public init(path: String, branch: String, isDirty: Bool = false) {
        self.path = path; self.branch = branch; self.isDirty = isDirty
    }
}
```

(The default parameter keeps every existing 2-argument call site —
including the `worktrees(repoPath:)` parser and existing tests — compiling
unchanged.)

- [ ] **Step 4: Add `GitService.isDirty`**

In `Sources/WorktreeCore/Git/GitService.swift`, insert this method
immediately after the closing brace of `worktrees(repoPath:)` (which ends
with `return result` around line 46), before `addWorktree`:

```swift
    /// True if the worktree has any uncommitted changes (tracked or
    /// untracked). `git status --porcelain` prints one line per dirty path
    /// and nothing when clean.
    public func isDirty(worktreePath: String) throws -> Bool {
        let out = try git(["-C", worktreePath, "status", "--porcelain"])
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter GitServiceTests`
Expected: PASS, all tests including the 5 new ones.

- [ ] **Step 6: Run the full suite to check nothing else broke**

Run: `swift test`
Expected: PASS (the `Worktree` default-param change must not break
`WorktreeCreatorTests`, `RepoScannerTests`, or any other equality check).

- [ ] **Step 7: Commit**

```bash
git add Sources/WorktreeCore/Models/Repo.swift Sources/WorktreeCore/Git/GitService.swift Tests/WorktreeCoreTests/GitServiceTests.swift
git commit -m "feat: add GitService.isDirty + Worktree.isDirty field"
```

---

### Task 2: Wire `isDirty` into `AppState.refresh()`

**Files:**
- Modify: `Sources/WorktreeGUI/AppState.swift` (the `refresh()` method, lines ~29-54)

**Interfaces:**
- Consumes: `GitService.isDirty(worktreePath:) throws -> Bool` and
  `Worktree.isDirty` from Task 1.
- Produces: `state.worktreesByRepo` entries now carry a real `isDirty` value
  instead of the struct default `false` — consumed by Task 5 (status dot UI).

- [ ] **Step 1: Update the refresh loop**

In `Sources/WorktreeGUI/AppState.swift`, inside `refresh()`, replace:

```swift
            for repo in scanned {
                try? git.prune(repoPath: repo.path)   // drop stale (deleted-folder) entries
                let all = (try? git.worktrees(repoPath: repo.path)) ?? []
                // Exclude the base repo's own checkout and any worktree whose
                // directory no longer exists on disk.
                map[repo.path] = all.filter { $0.path != repo.path && fm.fileExists(atPath: $0.path) }
            }
```

with:

```swift
            for repo in scanned {
                try? git.prune(repoPath: repo.path)   // drop stale (deleted-folder) entries
                let all = (try? git.worktrees(repoPath: repo.path)) ?? []
                // Exclude the base repo's own checkout and any worktree whose
                // directory no longer exists on disk.
                let filtered = all.filter { $0.path != repo.path && fm.fileExists(atPath: $0.path) }
                map[repo.path] = filtered.map { wt in
                    var wt = wt
                    wt.isDirty = (try? git.isDirty(worktreePath: wt.path)) ?? false
                    return wt
                }
            }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly, no errors.

- [ ] **Step 3: Run the full test suite (no behavior in WorktreeCoreTests should change)**

Run: `swift test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/AppState.swift
git commit -m "feat: populate Worktree.isDirty during refresh"
```

---

### Task 3: Theme tokens — near-black canvas, rail width, status-dot colors

**Files:**
- Modify: `Sources/WorktreeGUI/Theme.swift`
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift:7-8, 61-68` (surfaces)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Theme.canvas: Color`, `Theme.railWidth: CGFloat`,
  `Theme.dotClean: Color`, `Theme.dotDirty: Color` — consumed by Task 4
  (sidebar rail), Task 5 (status dot), Task 6 (Settings card fill).
  `VisualEffect` and the `reduceTransparency` surface branch are removed.

- [ ] **Step 1: Add the new tokens to `Theme.swift`**

In `Sources/WorktreeGUI/Theme.swift`, inside `enum Theme`, after the
existing `hairline` line (line 24), add:

```swift
    // MARK: Canvas — flat near-black surface (replaces native vibrancy)
    static let canvas = Color(red: 0.05, green: 0.05, blue: 0.055)

    // MARK: Layout
    static let railWidth: CGFloat = 64

    // MARK: Status dots — distinct from `accent` so a dirty dot never reads
    // as a selection indicator.
    static let dotClean = Color(nsColor: .systemGreen)
    static let dotDirty = Color(nsColor: .systemRed)
```

- [ ] **Step 2: Update the file's header doc comment**

Replace lines 4-10 (the `enum Theme` doc comment):

```swift
/// Design tokens, tuned to read as a first-party macOS menubar app.
///
/// The surface is native vibrancy (the desktop shows through, like Control
/// Center or the Wi-Fi popover), not a hardcoded near-black. Color follows the
/// system accent rather than a fixed brand hue, and type is SF Pro for chrome
/// with SF Mono kept for the things that are literally code — branch folders
/// and paths. Everything sits on an 8pt rhythm.
```

with:

```swift
/// Design tokens for Jig's OpenUsage-inspired visual language.
///
/// The surface is a flat near-black canvas (`Theme.canvas`), not native
/// vibrancy — a deliberate departure from the system-chrome look so the app
/// reads as its own branded dashboard. Color still centers on one signal hue
/// (`Brand.signalOrange`); type is SF Pro for chrome with SF Mono kept for
/// the things that are literally code — branch folders and paths. Everything
/// sits on an 8pt rhythm.
```

- [ ] **Step 3: Delete the now-unused `VisualEffect` wrapper**

In `Sources/WorktreeGUI/Theme.swift`, delete the entire `// MARK: - Vibrancy`
section (the comment line plus the `VisualEffect` struct that follows it,
currently lines 56-76).

- [ ] **Step 4: Simplify the sidebar/detail surfaces in `MenuContentView.swift`**

Remove the now-unused environment property at line 8:

```swift
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
```

Replace the surfaces block (lines 61-68):

```swift
    @ViewBuilder private var sidebarSurface: some View {
        if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
        else { VisualEffect(material: .sidebar) }
    }
    @ViewBuilder private var detailSurface: some View {
        if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
        else { VisualEffect(material: .headerView) }
    }
```

with:

```swift
    private var sidebarSurface: some View { Theme.canvas }
    private var detailSurface: some View { Theme.canvas }
```

- [ ] **Step 5: Build to verify it compiles**

Run: `swift build`
Expected: builds cleanly. No references to `VisualEffect` or
`reduceTransparency` remain in `MenuContentView.swift`.

Run: `grep -rn "VisualEffect\|reduceTransparency" Sources/WorktreeGUI`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeGUI/Theme.swift Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "feat: near-black canvas tokens, drop vibrancy surfaces"
```

---

### Task 4: Sidebar → narrow icon rail

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift` (the `sidebar`
  computed property, lines ~98-136, and `repoRow`, lines ~138-189; the
  `HStack` frame width at line 30)

**Interfaces:**
- Consumes: `Theme.railWidth`, `Theme.canvas`, `Brand.signalOrange`,
  `AccentSpine` (existing component, unchanged), `JigMark` (existing
  component, unchanged).
- Produces: no new public symbols — internal view restructuring only.

- [ ] **Step 1: Narrow the sidebar frame**

In `Sources/WorktreeGUI/Views/MenuContentView.swift`, in `body`, replace:

```swift
                sidebar
                    .frame(width: 200)
```

with:

```swift
                sidebar
                    .frame(width: Theme.railWidth)
```

- [ ] **Step 2: Replace the wordmark header with an icon-only mark**

Replace the top header block of `sidebar` (lines 100-104):

```swift
            HStack {
                JigWordmark(size: 15)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 2)
```

with:

```swift
            JigMark()
                .frame(width: 22, height: 22)
                .foregroundStyle(Brand.signalOrange)
                .frame(maxWidth: .infinity)
                .padding(.top, 14).padding(.bottom, 10)
```

- [ ] **Step 3: Remove the "Depolar" section label**

Delete the section-label block (lines 106-113):

```swift
            HStack(spacing: 6) {
                BrandBracket(size: 9)
                Text(state.t(.sidebarRepos))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
```

(No replacement — the rail has no room for a section header, matching the
OpenUsage reference, which has none either.)

- [ ] **Step 4: Narrow the repo-list padding**

In the `ScrollView` block, replace `.padding(.horizontal, 8)` with
`.padding(.horizontal, 6)` so the rail's avatar badges have even side
margins at the new narrower width:

```swift
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(state.repos.enumerated()), id: \.element.id) { idx, repo in
                        repoRow(repo, index: idx)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
```

- [ ] **Step 5: Rewrite `repoRow` as an icon-rail badge**

Replace the entire `repoRow(_:index:)` method (lines 138-189):

```swift
    private func repoRow(_ repo: Repo, index: Int) -> some View {
        let isSelected = pane == .repo && selectedRepo?.path == repo.path
        let isHovered = hoveredRepoPath == repo.path
        let initial = String(repo.name.prefix(1)).uppercased()
        return Button {
            withAnimation(selectAnim) { selectedRepoPath = repo.path; pane = .repo }
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent : Color.primary.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initial)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovered && !isSelected ? Theme.hover : .clear)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .overlay(alignment: .leading) {
                    if isSelected {
                        AccentSpine().padding(.vertical, 6)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredRepoPath = $0 ? repo.path : (isHovered ? nil : hoveredRepoPath) }
        .help("\(repo.group)/\(repo.name)  ·  \(index + 1)")
    }
```

- [ ] **Step 6: Build and manually verify**

Run: `swift build`
Expected: builds cleanly.

Run `./scripts/build-app.sh`, launch the app, open the menubar popover.
Confirm: sidebar is now a narrow column of rounded-square initial badges,
selected repo shows the orange fill + left accent spine, hovering a tooltip
shows `group/name · index`, pressing `1`-`9` still jumps between repos.

- [ ] **Step 7: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "feat: sidebar becomes a narrow icon rail"
```

---

### Task 5: Worktree row — git dirty/clean status dot

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift` (`worktreeRow`,
  lines ~289-341)

**Interfaces:**
- Consumes: `Worktree.isDirty` (Task 1/2), `Theme.dotClean`,
  `Theme.dotDirty` (Task 3).
- Produces: nothing new — internal view change only.

- [ ] **Step 1: Add the status dot before the branch icon**

In `Sources/WorktreeGUI/Views/MenuContentView.swift`, inside
`worktreeRow(repo:wt:)`, replace:

```swift
        HStack(spacing: 11) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovered ? Theme.accent : Theme.textTertiary)
                .frame(width: 16)
```

with:

```swift
        HStack(spacing: 11) {
            Circle()
                .fill(wt.isDirty ? Theme.dotDirty : Theme.dotClean)
                .frame(width: 6, height: 6)
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovered ? Theme.accent : Theme.textTertiary)
                .frame(width: 16)
```

- [ ] **Step 2: Build and manually verify**

Run: `swift build`
Expected: builds cleanly.

Run `./scripts/build-app.sh`, launch, open a repo with worktrees. Make an
uncommitted edit in one worktree's directory. Click refresh in the popover.
Confirm: the edited worktree's row shows a red dot, untouched worktrees show
green.

- [ ] **Step 3: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "feat: git dirty/clean status dot on worktree rows"
```

---

### Task 6: Settings pane restyle

**Files:**
- Modify: `Sources/WorktreeGUI/Theme.swift` (`LiquidTabs`/`GlassIndicator`,
  lines ~152-200)
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift` (`section` helper,
  lines 136-161; language picker, lines 31-41; scan-depth picker, lines
  59-64)

**Interfaces:**
- Consumes: `Theme.canvas` (Task 3).
- Produces: `LiquidTabs(selection:tabs:selectedFill:)` — a new optional
  `selectedFill` parameter (defaults to `Theme.accent`, so the existing
  `NewWorktreeView` call site is unaffected); consumed by `SettingsView`'s
  two restyled pickers.

- [ ] **Step 1: Add a `selectedFill` parameter to `LiquidTabs`**

In `Sources/WorktreeGUI/Theme.swift`, replace the `LiquidTabs` struct
(lines 152-187):

```swift
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
```

with:

```swift
struct LiquidTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let tabs: [(value: Value, title: String)]
    var selectedFill: Color = Theme.accent
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
                        .foregroundStyle(isSel ? (selectedFill == Theme.accent ? .white : Color.black) : Theme.textSecondary)
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
```

Then replace `GlassIndicator` (the struct immediately below it, lines
189-200):

```swift
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
```

with:

```swift
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
```

(`NewWorktreeView.swift:39`'s existing `LiquidTabs(selection: $mode, tabs:
...)` call omits `selectedFill`, so it keeps using `Theme.accent` — its
appearance is unchanged.)

- [ ] **Step 2: Restyle the `section` card fill**

In `Sources/WorktreeGUI/Views/SettingsView.swift`, replace the `content()`
background/overlay block inside `section(_:_:content:)` (lines 149-159):

```swift
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
```

with:

```swift
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.canvas)
                )
```

- [ ] **Step 3: Switch the language picker to `LiquidTabs`**

Replace the language-picker section body (lines 32-40):

```swift
                section(state.t(.languageTitle), state.t(.languageCaption)) {
                    Picker("", selection: Binding(
                        get: { state.language },
                        set: { state.setLanguage($0) }
                    )) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
```

with:

```swift
                section(state.t(.languageTitle), state.t(.languageCaption)) {
                    LiquidTabs(
                        selection: Binding(get: { state.language }, set: { state.setLanguage($0) }),
                        tabs: Language.allCases.map { (value: $0, title: $0.label) },
                        selectedFill: .white
                    )
                }
```

- [ ] **Step 4: Switch the scan-depth picker to `LiquidTabs`**

Replace the scan-depth section body (lines 59-64):

```swift
                section(state.t(.scanDepthTitle), state.t(.scanDepthCaption)) {
                    Picker("", selection: depthBinding) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
```

with:

```swift
                section(state.t(.scanDepthTitle), state.t(.scanDepthCaption)) {
                    LiquidTabs(
                        selection: depthBinding,
                        tabs: (1...5).map { (value: $0, title: "\($0)") },
                        selectedFill: .white
                    )
                }
```

- [ ] **Step 5: Build and manually verify**

Run: `swift build`
Expected: builds cleanly.

Run `./scripts/build-app.sh`, open Settings. Confirm: section cards now sit
on a near-black fill with no border, Language and Scan Depth controls are
white pill-style tabs (matching the OpenUsage System/Light/Dark reference),
and the New Worktree form's existing/new-branch tabs still look exactly as
before (still orange-accented).

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeGUI/Theme.swift Sources/WorktreeGUI/Views/SettingsView.swift
git commit -m "feat: restyle Settings pane — canvas cards, LiquidTabs pickers"
```

---

### Task 7: Settings card tonal depth (addendum Fix A)

**Files:**
- Modify: `Sources/WorktreeGUI/Theme.swift` (add a token after `canvas`, around line 28)
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift:151-154` (the `section(_:_:content:)` card background)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Theme.surfaceRaised: Color` — consumed only by `SettingsView`'s
  card background in this task. (Not reused by Task 8 — rail badges get
  their own per-repo colors, not this neutral token.)

- [ ] **Step 1: Add the token**

In `Sources/WorktreeGUI/Theme.swift`, immediately after the existing line

```swift
    static let canvas = Color(red: 0.05, green: 0.05, blue: 0.055)
```

add:

```swift

    /// One step lighter than `canvas` — gives cards/rows visible separation
    /// from the page behind them instead of sitting at the identical tone.
    static let surfaceRaised = Color(red: 0.11, green: 0.11, blue: 0.12)
```

- [ ] **Step 2: Use it in the Settings card background**

In `Sources/WorktreeGUI/Views/SettingsView.swift`, replace:

```swift
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.canvas)
                )
```

with:

```swift
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surfaceRaised)
                )
```

- [ ] **Step 3: Build and verify**

Run: `swift build` — must succeed.
Run: `swift test` — all 55 tests must still pass.
Run: `./scripts/build-app.sh` — must package successfully.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Theme.swift Sources/WorktreeGUI/Views/SettingsView.swift
git commit -m "feat: tonal depth for Settings cards (Theme.surfaceRaised)"
```

---

### Task 8: Per-repo rail avatar color (addendum Fix B)

**Files:**
- Modify: `Sources/WorktreeGUI/Theme.swift` (add a palette + hash function, near the bottom of `enum Theme`, after the `mono(_:_:)` function)
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift:130, 135` (the `repoRow` badge fill and initial text color)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Theme.avatarColor(for:) -> Color` — consumed only by `repoRow`'s
  unselected badge fill in this task.

- [ ] **Step 1: Add the palette + deterministic hash to `Theme.swift`**

In `Sources/WorktreeGUI/Theme.swift`, inside `enum Theme`, immediately before
the closing brace of the enum (after the existing `mono(_:_:)` static
function), add:

```swift

    // MARK: Rail avatar palette — deterministic per-repo hue, distinct from
    // `accent` so an unselected badge's color is never mistaken for the
    // selected-state signal.
    static let avatarPalette: [Color] = [
        Color(nsColor: .systemBlue),
        Color(nsColor: .systemTeal),
        Color(nsColor: .systemIndigo),
        Color(nsColor: .systemPurple),
        Color(nsColor: .systemPink),
        Color(nsColor: .systemMint),
    ]

    /// Stable per-repo color hashed from the repo name. Deliberately not
    /// `String.hashValue` — that's randomized per process, so the same repo
    /// would get a different color on every relaunch. djb2 over UTF8 bytes
    /// is deterministic across runs.
    static func avatarColor(for name: String) -> Color {
        var hash: UInt64 = 5381
        for byte in name.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        let index = Int(hash % UInt64(avatarPalette.count))
        return avatarPalette[index].opacity(0.55)
    }
```

- [ ] **Step 2: Use it in `repoRow`**

In `Sources/WorktreeGUI/Views/MenuContentView.swift`, inside `repoRow(_:index:)`,
replace:

```swift
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent : Color.primary.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initial)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                }
```

with:

```swift
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent : Theme.avatarColor(for: repo.name))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initial)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                }
```

(Text goes from `Theme.textSecondary` to `.white.opacity(0.85)` because the
badge background is no longer a uniform near-black gray — it's now one of
six saturated hues at 55% opacity, and a gray label doesn't read reliably
against all six. White-at-reduced-opacity does, while still staying clearly
less prominent than the full-white selected-state label.)

- [ ] **Step 3: Build and verify**

Run: `swift build` — must succeed.
Run: `swift test` — all 55 tests must still pass.
Run: `./scripts/build-app.sh` — must package successfully.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Theme.swift Sources/WorktreeGUI/Views/MenuContentView.swift
git commit -m "feat: deterministic per-repo color for rail avatar badges"
```

---

### Task 9: Full-suite regression check + final manual pass

**Files:** none (verification only)

**Interfaces:** none.

- [ ] **Step 1: Run the full WorktreeCore test suite**

Run: `swift test`
Expected: PASS, all tests including the 5 added in Task 1.

- [ ] **Step 2: Build the app bundle**

Run: `./scripts/build-app.sh`
Expected: succeeds, produces `WorktreeGUI.app` in the project root.

- [ ] **Step 3: Manual walkthrough**

Launch the app, open the menubar popover, and confirm against the spec
(`docs/superpowers/specs/2026-06-30-openusage-style-restyle-design.md`,
including the 2026-06-30 addendum):
- Near-black canvas on both sidebar and detail panes (no vibrancy/desktop
  show-through).
- Sidebar is a narrow icon rail; 1-9 keyboard shortcuts still work; hover
  tooltips show full repo name + group.
- Rail badges: repos with the same first letter (e.g. the user's
  `example-admin`/`example-individual`/`example-student`/`ekurs`) now show visibly
  different colors, not identical gray squares.
- Settings pane: cards are visibly lighter than the page background (not
  the same flat black), white pill tabs for Language and Scan Depth.
- Worktree rows show a green/red status dot reflecting actual git dirty
  state (verify by editing a file in one worktree and refreshing).
- New Worktree form's tabs are unchanged (still orange).

- [ ] **Step 4: Report results to the user — no commit (verification only)**
