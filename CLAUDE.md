# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

WorktreeGUI is a macOS menubar-only app (`LSUIElement`/`.accessory` — no dock icon) for creating and managing `git worktree`s across many local repos. The user scans roots like `~/Dev`, picks a repo, and creates a worktree on a new or existing branch; the app applies `.env` rules, runs package-manager install + setup commands, and opens the worktree in an editor/terminal.

## Commands

```bash
swift build                              # debug build
swift test                               # run all tests (WorktreeCoreTests only)
swift test --filter WorktreeCreatorTests # one test class
swift test --filter WorktreeCreatorTests/testCreateRunsSetupCommands  # one test
swift run WorktreeGUI                    # run from terminal (menubar item appears)

./scripts/build-app.sh                   # build WorktreeGUI.app bundle (ad-hoc signed) in project root
./scripts/build-app.sh --install         # also copy to /Applications
```

Tooling: Swift Package Manager, `swift-tools-version: 5.9`, macOS 14+. No external dependencies. There is no linter configured.

## Architecture

Two targets with a hard one-way dependency:

- **`WorktreeCore`** (library) — all logic, no SwiftUI/AppKit. Fully unit-tested. **All tests live here**; the GUI target has no tests.
- **`WorktreeGUI`** (executable) — SwiftUI menubar app. Depends on `WorktreeCore`. Keep AppKit/SwiftUI out of Core.

### The ProcessRunner seam

Every external command (git, `open`, `sh -c`, package-manager installs) goes through the `ProcessRunner` protocol — the single seam that makes Core testable. Production uses `SystemProcessRunner` (shells out via `/usr/bin/env`); tests inject `FakeProcessRunner`, which records every `Call` and returns queued `ProcessResult`s. **Any new code that touches the system must take a `ProcessRunner`, not call `Process` directly**, or it becomes untestable. Services built on this seam: `GitService`, `Launcher`, `SetupRunner`.

Two non-obvious `SystemProcessRunner` details: it drains stdout/stderr pipes on concurrent queues (reading one to EOF first deadlocks when the other fills its ~64KB buffer), and it injects Homebrew/`/usr/local/bin`/`~/.local/bin` into `PATH` because a Finder-launched GUI gets a minimal PATH where `cursor`/`npm`/etc. don't resolve.

### Creation pipeline

`WorktreeCreator.create` is the orchestrator. Order matters and is intentional:
1. If creating a new branch off a base, `git fetch origin <base>` and retarget to `origin/<base>` so the branch starts from the latest remote tip. Non-fatal — offline falls back to the local base.
2. `git worktree add`.
3. Apply env rules (`SetupRunner.applyEnvRules`) — writes resolved `.env` files into the worktree.
4. Package-manager install (`yarn install`/`npm install`) — **before** custom setup commands so deps exist for them.
5. Custom `setupCommands`.

The long-running dev server (`yarn dev`/`npm run dev`) is **not** run here — `AppState.createWorktree` starts it in a terminal after creation so the worktree "arrives running".

### Config & placeholders

Config is a single JSON file at `~/.config/worktree-gui/config.json` (`ConfigStore`). `Config.init(from:)` decodes resiliently — missing keys fall back to `Config.default` rather than throwing, so hand-edited/older files still load.

Per-repo settings are keyed by `"{group}/{repo}"`. Resolution is always **repo-specific value, else `defaults`** (see `RepoSettings?.x ?? config.defaults.x` throughout). Path/command templates use `{group} {repo} {type} {taskName} {branch}` placeholders resolved by `PlaceholderResolver`, which throws on an unknown token. Default worktree path template: `{group}/task/{type}-{taskName}`. `{type}` falls back to the substring after the first `-` in the repo name.

`RepoScanner` walks each scan root up to `scanDepth`, stops descending at the first `.git` it finds (treats a `.git` dir as a base repo, a `.git` file as a worktree and skips it). `group` = repo's parent dir name; the worktree "root" is the repo's grandparent (`<root>/<group>/<repo>`).

### GUI

`WorktreeGUIApp` → `MenuBarExtra(... .window)` → `MenuContentView` (master-detail: repo list + New Worktree / Settings panes in `Views/`). `AppState` (`@MainActor ObservableObject`) is the single source of truth and the only bridge into Core. Scanning and per-repo `git worktree list` run on `Task.detached` off the main thread so the popover never freezes; results are published back via `MainActor.run`. `Theme.swift` holds styling — see the design-direction notes below before changing visuals.

## Conventions

- Code comments and some UI strings are in **Turkish** (mixed with English). Match the surrounding language when editing a file; UI-facing strings are currently Turkish.
- Core models are value types (`struct`/`enum`), `Codable`/`Equatable` where they cross the persistence or test boundary.
- Errors are typed enums per service (`GitError`, `LaunchError`, `SetupError`, `PlaceholderError`) carrying the failing command + stderr.
- Tests use a queued-results `FakeProcessRunner` and assert on the recorded `calls` array (exact executable + args). Follow that pattern for new Core code.

## Design skills

`.agents/skills/` contains `macos-design-guidelines` and `swiftui-expert-skill` (SKILL.md each) — consult them when changing UI. The app's current visual direction is Apple-native (system accent + vibrancy + SF Pro source-list).
