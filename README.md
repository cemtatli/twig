# Twig

A macOS **menubar app for managing `git worktree`s across many local repos.**
Scan your dev folders, pick a repo, and spin up a worktree on a new or existing
branch — Twig applies your `.env` rules, runs the package-manager install, runs
your setup commands, and opens the worktree in your editor and terminal with the
dev server already running.

Twig lives only in the menu bar (no Dock icon) and is dark-only by design.

---

## Requirements

- macOS 14 (Sonoma) or later
- [Swift toolchain](https://www.swift.org/install/) (ships with Xcode or the Command Line Tools) — only needed to build
- Optional at runtime: `git`, your editor (`Cursor` by default), a terminal, and `yarn`/`npm` if you use the install/dev automation

No external Swift dependencies.

## Install

Build the double-clickable `.app` bundle and drop it in `/Applications`:

```bash
git clone <your-fork-url> twig
cd twig
./scripts/build-app.sh --install
```

Then launch **Twig** from Spotlight or Launchpad — a small mark appears in your
menu bar. Click it to open the panel.

The bundle is **ad-hoc signed**, so on first launch macOS Gatekeeper may block
it. Right-click the app → **Open**, or allow it under **System Settings →
Privacy & Security**.

Prefer to run it without installing?

```bash
swift run Twig
```

## Using Twig

1. **Scan roots.** Open **Settings** and set the folders Twig walks for repos
   (default `~/Dev`). It descends up to `scanDepth` levels and stops at the
   first `.git` it finds.
2. **Pick a repo** from the sidebar.
3. **New Worktree.** Choose a new or existing branch, a task name, and a base
   branch. Twig then:
   - fetches the base from `origin` so the new branch starts at the latest
     remote tip (falls back to your local base when offline),
   - runs `git worktree add`,
   - writes your resolved `.env` files,
   - runs the package-manager install (`yarn install` / `npm install`),
   - runs your custom setup commands,
   - opens the worktree in your editor and a terminal, and starts the dev
     server (`yarn dev` / `npm run dev`) so the worktree "arrives running".

### Path & command placeholders

Worktree paths and commands are templates. Available tokens:

| Token         | Meaning                                                        |
|---------------|----------------------------------------------------------------|
| `{group}`     | Repo's parent directory name                                   |
| `{repo}`      | Repo name                                                      |
| `{type}`      | Repo "type" — the substring after the first `-` in the name    |
| `{taskName}`  | Task name you enter when creating the worktree                 |
| `{branch}`    | Branch name                                                    |

Default worktree path: `{group}/task/{type}-{taskName}`.

## Configuration

Everything is stored in one global JSON file:

```
~/.config/twig/config.json
```

It is created on first run and decodes resiliently — missing keys fall back to
defaults, so you can hand-edit it safely. Key fields:

| Field                     | Default                              | Description                                                        |
|---------------------------|--------------------------------------|--------------------------------------------------------------------|
| `scanRoots`               | `["~/Dev"]`                          | Folders scanned for repos                                          |
| `scanDepth`               | `3`                                  | How deep to walk each root                                         |
| `manualRepos`             | `[]`                                 | Extra repo paths added by hand                                     |
| `terminalApp`             | `"Terminal"`                         | Terminal opened after creation                                     |
| `editorApp`               | `"Cursor"`                           | Editor opened after creation                                       |
| `terminalStartupCommand`  | `""`                                 | Optional command run in the terminal on open                       |
| `language`                | `"en"`                               | UI language                                                        |
| `defaults`                | see below                            | Fallback settings for any repo without its own overrides           |
| `repos`                   | `{}`                                 | Per-repo overrides, keyed by `"{group}/{repo}"`                    |

Per-repo settings (`repos["group/repo"]`) can override `type`, `worktreePath`,
`defaultBase`, `envRules`, `setupCommands`, and `packageManager`. Resolution is
always **the repo-specific value, else `defaults`**.

Example:

```json
{
  "scanRoots": ["~/Dev", "~/Work"],
  "scanDepth": 3,
  "editorApp": "Cursor",
  "terminalApp": "Terminal",
  "defaults": {
    "worktreePath": "{group}/task/{type}-{taskName}",
    "defaultBase": "main"
  },
  "repos": {
    "acme/acme-web": {
      "packageManager": "yarn",
      "defaultBase": "develop",
      "envRules": [
        { "file": ".env.local", "key": "API_URL", "value": "http://localhost:4000" }
      ],
      "setupCommands": ["yarn codegen"]
    }
  }
}
```

## Development

```bash
swift build                              # debug build
swift test                               # run the test suite (TwigCore)
swift run Twig                           # run from the terminal
./scripts/build-app.sh                   # build Twig.app in the project root
```

### Architecture

Two Swift Package targets with a one-way dependency:

- **`TwigCore`** — all logic, no SwiftUI/AppKit. Fully unit-tested.
- **`Twig`** — the SwiftUI menubar app. Depends on `TwigCore`.

Every external command (git, `open`, `sh -c`, installs) goes through the
`ProcessRunner` protocol — the single seam that keeps `TwigCore` testable.
Production shells out via `SystemProcessRunner`; tests inject a
`FakeProcessRunner` that records calls and returns queued results.

## License

_No license chosen yet._ Add a `LICENSE` file (e.g. MIT) before publishing —
without one, the code is "all rights reserved" by default.
