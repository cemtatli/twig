# Jig Branding & Design-System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the menubar app to **Jig** — clamp-J mark, signal-orange accent over preserved vibrancy, and English-default UI with a Turkish toggle.

**Architecture:** Add a pure-Foundation localization layer (`Language` + `L10n`) to `WorktreeCore` so string lookup is unit-testable; route every visible GUI string through `AppState.t(_:)`. Swap the system accent for a brand `signalOrange` token in `Theme`, add a custom `JigMark`/`JigWordmark`, and replace the menubar SF Symbol with a template-rendered clamp-J. Worktree creation/scan logic is untouched.

**Tech Stack:** Swift 5.9, Swift Package Manager, SwiftUI + AppKit, macOS 14+. No new dependencies. `WorktreeCore` (logic, unit-tested) → `WorktreeGUI` (SwiftUI, build + visual verification only — there are no GUI unit tests in this repo).

## Global Constraints

- Brand accent: `signalOrange = #FF6A1A` (`Color(red: 1.0, green: 0.416, blue: 0.102)`). It replaces `Color.accentColor` as `Theme.accent`.
- Destructive stays red: `Theme.danger = Color(nsColor: .systemRed)`. Orange is never used for destructive actions.
- Vibrancy, SF Pro chrome, SF Mono-for-code, source-list sidebar, 8pt grid, and all Reduce-Motion/Reduce-Transparency gating stay intact.
- Default language is English (`"en"`); Turkish (`"tr"`) is selectable in Settings.
- `WorktreeCore` must not import SwiftUI/AppKit.
- Keep the existing config path `~/.config/worktree-gui/config.json`; `Config` decoding stays resilient (missing keys → defaults).
- Verify GUI tasks by **running the app** (see `memory/worktree-gui-screenshot-howto`), not just building.
- Commit after every task.

---

### Task 1: `Config.language` field

**Files:**
- Modify: `Sources/WorktreeCore/Models/Config.swift`
- Test: `Tests/WorktreeCoreTests/ConfigStoreTests.swift`

**Interfaces:**
- Produces: `Config.language: String` (default `"en"`), decoded resiliently.

- [ ] **Step 1: Write the failing test**

Add to `ConfigStoreTests.swift`:

```swift
func testLanguageDefaultsToEnglishWhenMissing() throws {
    let json = #"{"scanRoots":["~/Dev"]}"#.data(using: .utf8)!
    let config = try JSONDecoder().decode(Config.self, from: json)
    XCTAssertEqual(config.language, "en")
}

func testLanguageDecodesWhenPresent() throws {
    let json = #"{"language":"tr"}"#.data(using: .utf8)!
    let config = try JSONDecoder().decode(Config.self, from: json)
    XCTAssertEqual(config.language, "tr")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConfigStoreTests/testLanguageDefaultsToEnglishWhenMissing`
Expected: FAIL — `value of type 'Config' has no member 'language'`.

- [ ] **Step 3: Add the field**

In `Config.swift`, add the stored property, init param, coding key, decode line, and default.

```swift
// property (after editorApp / terminalStartupCommand group)
public var language: String
```
```swift
// init signature — add parameter with default
                terminalStartupCommand: String = "", language: String = "en",
```
```swift
// init body — assign
        self.terminalStartupCommand = terminalStartupCommand
        self.language = language
```
```swift
// CodingKeys — add `language`
        case terminalStartupCommand, language, repos, defaults
```
```swift
// init(from:) — resilient decode
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
```
```swift
// Config.default — add argument
        terminalStartupCommand: "",
        language: "en",
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConfigStoreTests`
Expected: PASS (all existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/Models/Config.swift Tests/WorktreeCoreTests/ConfigStoreTests.swift
git commit -m "feat: add Config.language field (en default, resilient decode)"
```

---

### Task 2: `Language` enum + `L10n` string table

**Files:**
- Create: `Sources/WorktreeCore/L10n/L10n.swift`
- Test: `Tests/WorktreeCoreTests/L10nTests.swift`

**Interfaces:**
- Produces:
  - `enum Language: String, Codable, CaseIterable { case en, tr }` with `var label: String` (`"English"` / `"Türkçe"`).
  - `enum L10nKey: String` — one case per visible string (full set below).
  - `enum L10n { static func string(_ key: L10nKey, language: Language) -> String; static func worktreeCount(_ n: Int, language: Language) -> String }`.
  - Lookup falls back to English, then to the key's raw value, when a string is missing.

- [ ] **Step 1: Write the failing test**

Create `Tests/WorktreeCoreTests/L10nTests.swift`:

```swift
import XCTest
@testable import WorktreeCore

final class L10nTests: XCTestCase {
    func testEnglishLookup() {
        XCTAssertEqual(L10n.string(.create, language: .en), "Create")
    }
    func testTurkishLookup() {
        XCTAssertEqual(L10n.string(.create, language: .tr), "Oluştur")
    }
    func testEveryKeyHasBothLanguages() {
        for key in L10nKey.allCases {
            XCTAssertFalse(L10n.string(key, language: .en).isEmpty, "EN missing: \(key)")
            XCTAssertFalse(L10n.string(key, language: .tr).isEmpty, "TR missing: \(key)")
        }
    }
    func testWorktreeCountPluralizes() {
        XCTAssertEqual(L10n.worktreeCount(1, language: .en), "1 worktree")
        XCTAssertEqual(L10n.worktreeCount(3, language: .en), "3 worktrees")
        XCTAssertEqual(L10n.worktreeCount(3, language: .tr), "3 worktree")
    }
    func testLanguageLabels() {
        XCTAssertEqual(Language.en.label, "English")
        XCTAssertEqual(Language.tr.label, "Türkçe")
    }
}
```

Note: `L10nKey` must conform to `CaseIterable` for `testEveryKeyHasBothLanguages`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter L10nTests`
Expected: FAIL — `cannot find 'L10n' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/WorktreeCore/L10n/L10n.swift`:

```swift
import Foundation

public enum Language: String, Codable, CaseIterable {
    case en, tr
    public var label: String { self == .en ? "English" : "Türkçe" }
    /// Resolve a stored raw value to a Language, defaulting to English.
    public static func from(_ raw: String) -> Language { Language(rawValue: raw) ?? .en }
}

public enum L10nKey: String, CaseIterable {
    // Sidebar / rail
    case sidebarRepos, addRepo, settings, quit, refresh, new, newWorktreeHelp
    case sidebarShow, sidebarHide, sidebarLabel
    // Repo detail + worktree rows
    case noWorktreesYet, createFirstWorktree, deletePrompt, worktreeWord, branchPlus
    case cancel, finder, delete, noRepositories, loading, pickFolderHint
    // New worktree form
    case newWorktreeTitle, existingBranch, newBranchTab, branch, newBranchName
    case branchPlaceholder, baseBranch, taskNameFolder, taskPlaceholder, working, close, create
    // Settings
    case settingsTitle, repoSourcesTitle, repoSourcesCaption, noSourcesYet
    case kindRoot, kindRepo, addFromFinder
    case scanDepthTitle, scanDepthCaption, terminalTitle, terminalCaption
    case editorTitle, editorCaption, packageManagerTitle, packageManagerCaption
    case noReposFound, startupCommandTitle, startupCommandCaption, startupPlaceholder
    case editConfigHint, pmNone, remove, languageTitle, languageCaption
    // Add-source panel
    case addPanelPrompt, addPanelMessage
}

public enum L10n {
    public static func string(_ key: L10nKey, language: Language) -> String {
        table[language]?[key] ?? table[.en]?[key] ?? key.rawValue
    }

    public static func worktreeCount(_ n: Int, language: Language) -> String {
        switch language {
        case .en: return n == 1 ? "1 worktree" : "\(n) worktrees"
        case .tr: return "\(n) worktree"
        }
    }

    private static let table: [Language: [L10nKey: String]] = [
        .en: [
            .sidebarRepos: "Repositories", .addRepo: "Add repo", .settings: "Settings",
            .quit: "Quit", .refresh: "Refresh", .new: "New", .newWorktreeHelp: "New worktree",
            .sidebarShow: "Show sidebar", .sidebarHide: "Hide sidebar", .sidebarLabel: "Sidebar",
            .noWorktreesYet: "No worktrees yet",
            .createFirstWorktree: "Create your first with \u{201C}New\u{201D}",
            .deletePrompt: "Delete?", .worktreeWord: "Worktree", .branchPlus: "+ Branch",
            .cancel: "Cancel", .finder: "Finder", .delete: "Delete",
            .noRepositories: "No repositories", .loading: "Loading\u{2026}",
            .pickFolderHint: "Pick a folder via \u{201C}Add repo\u{201D} on the left",
            .newWorktreeTitle: "New Worktree", .existingBranch: "Existing branch",
            .newBranchTab: "New branch", .branch: "Branch", .newBranchName: "New branch name",
            .branchPlaceholder: "e.g. feat/booking", .baseBranch: "Base branch (to copy)",
            .taskNameFolder: "Task name (folder)", .taskPlaceholder: "e.g. booking",
            .working: "Working\u{2026}", .close: "Close", .create: "Create",
            .settingsTitle: "Settings", .repoSourcesTitle: "Repository Sources",
            .repoSourcesCaption: "Pick a folder: one with .git is a single repo, others become scanned roots.",
            .noSourcesYet: "No sources yet", .kindRoot: "root", .kindRepo: "repo",
            .addFromFinder: "Add from Finder", .scanDepthTitle: "Scan Depth",
            .scanDepthCaption: "How many levels under a root to search",
            .terminalTitle: "Terminal", .terminalCaption: "Which terminal opens the worktree",
            .editorTitle: "Editor", .editorCaption: "Which editor opens the worktree",
            .packageManagerTitle: "Package Manager",
            .packageManagerCaption: "On selected repos, install runs after creation, then the dev server opens in a terminal.",
            .noReposFound: "No repositories found",
            .startupCommandTitle: "Terminal Startup Command",
            .startupCommandCaption: "Runs in the worktree when the terminal opens (optional). Save with Enter.",
            .startupPlaceholder: "e.g. npm run dev",
            .editConfigHint: "Edit config.json by hand for env/command rules:",
            .pmNone: "None", .remove: "Remove",
            .languageTitle: "Language", .languageCaption: "Interface language",
            .addPanelPrompt: "Add",
            .addPanelMessage: "Pick a repo folder or a root folder containing repos",
        ],
        .tr: [
            .sidebarRepos: "Depolar", .addRepo: "Repo ekle", .settings: "Ayarlar",
            .quit: "Çıkış", .refresh: "Yenile", .new: "Yeni", .newWorktreeHelp: "Yeni worktree",
            .sidebarShow: "Kenar çubuğunu göster", .sidebarHide: "Kenar çubuğunu gizle",
            .sidebarLabel: "Kenar çubuğu",
            .noWorktreesYet: "Henüz worktree yok",
            .createFirstWorktree: "\u{201C}Yeni\u{201D} ile ilk worktree\u{2019}yi oluştur",
            .deletePrompt: "Sil?", .worktreeWord: "Worktree", .branchPlus: "+ Branch",
            .cancel: "Vazgeç", .finder: "Finder", .delete: "Sil",
            .noRepositories: "Repo yok", .loading: "Yükleniyor\u{2026}",
            .pickFolderHint: "Soldaki \u{201C}Repo ekle\u{201D} ile bir klasör seç",
            .newWorktreeTitle: "Yeni Worktree", .existingBranch: "Var olan branch",
            .newBranchTab: "Yeni branch", .branch: "Branch", .newBranchName: "Yeni branch adı",
            .branchPlaceholder: "ör. feat/randevu", .baseBranch: "Base branch (kopyalanacak)",
            .taskNameFolder: "Task adı (klasör)", .taskPlaceholder: "ör. randevu",
            .working: "Çalışıyor\u{2026}", .close: "Kapat", .create: "Oluştur",
            .settingsTitle: "Ayarlar", .repoSourcesTitle: "Repo Kaynakları",
            .repoSourcesCaption: "Klasör seç: içinde .git olan tek repo, diğerleri taranan kök olur.",
            .noSourcesYet: "Henüz kaynak yok", .kindRoot: "kök", .kindRepo: "repo",
            .addFromFinder: "Finder\u{2019}dan Ekle", .scanDepthTitle: "Tarama Derinliği",
            .scanDepthCaption: "Kök altında kaç seviye derine bakılsın",
            .terminalTitle: "Terminal", .terminalCaption: "Worktree hangi terminalde açılsın",
            .editorTitle: "Editör", .editorCaption: "Worktree hangi editörde açılsın",
            .packageManagerTitle: "Paket Yöneticisi",
            .packageManagerCaption: "Seçili repolarda worktree oluşunca install çalışır, sonra dev sunucusu terminalde açılır.",
            .noReposFound: "Repo bulunamadı",
            .startupCommandTitle: "Terminal Başlangıç Komutu",
            .startupCommandCaption: "Terminal açılınca worktree\u{2019}de çalışır (opsiyonel). Enter ile kaydet.",
            .startupPlaceholder: "ör. npm run dev",
            .editConfigHint: "Env/komut kuralları için config.json\u{2019}ı elle düzenle:",
            .pmNone: "Yok", .remove: "Kaldır",
            .languageTitle: "Dil", .languageCaption: "Arayüz dili",
            .addPanelPrompt: "Ekle",
            .addPanelMessage: "Bir repo klasörü ya da repoları içeren bir kök klasör seç",
        ],
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter L10nTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeCore/L10n/L10n.swift Tests/WorktreeCoreTests/L10nTests.swift
git commit -m "feat: add Language enum + L10n EN/TR string table"
```

---

### Task 3: `AppState` localization helpers + localized panel/logs

**Files:**
- Modify: `Sources/WorktreeGUI/AppState.swift`

**Interfaces:**
- Consumes: `L10n`, `L10nKey`, `Language`, `Config.language`.
- Produces:
  - `var language: Language { Language.from(config.language) }`
  - `func t(_ key: L10nKey) -> String`
  - `func worktreeCountText(_ n: Int) -> String`
  - `func setLanguage(_ lang: Language)` — sets `config.language` and saves.

- [ ] **Step 1: Add helpers to `AppState`**

Add inside `AppState` (e.g. after `defaultBase(for:)`):

```swift
var language: Language { Language.from(config.language) }
func t(_ key: L10nKey) -> String { L10n.string(key, language: language) }
func worktreeCountText(_ n: Int) -> String { L10n.worktreeCount(n, language: language) }
func setLanguage(_ lang: Language) {
    config.language = lang.rawValue
    saveConfig()
}
```

- [ ] **Step 2: Localize the add-source panel**

In `addReposViaPanel()`, replace the hardcoded Turkish:

```swift
        panel.prompt = t(.addPanelPrompt)
        panel.message = t(.addPanelMessage)
```

(was `panel.prompt = "Ekle"` and `panel.message = "Bir repo klasörü…"`)

- [ ] **Step 3: English-ify the creation log line**

In `createWorktree(_:)`, change the Turkish log suffix to English (logs are English-only, not localized):

```swift
                        self.log.append("$ \(pm.devCommand)  (in terminal)")
```

(was `"… (terminalde)"`)

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/WorktreeGUI/AppState.swift
git commit -m "feat: AppState localization helpers (t/language/setLanguage) + localized panel"
```

---

### Task 4: Brand tokens in `Theme`

**Files:**
- Modify: `Sources/WorktreeGUI/Theme.swift`

**Interfaces:**
- Produces: `Theme.accent` now returns the brand orange; `Brand.signalOrange` available.

- [ ] **Step 1: Add the brand token and repoint `accent`**

Replace the accent/state block in `Theme`:

```swift
    // MARK: Accent + state — brand signal, not the system accent
    static let accent = Brand.signalOrange
    static let danger = Color(nsColor: .systemRed)
```

(was `static let accent = Color.accentColor`)

Add a `Brand` enum at file scope (below `Theme`):

```swift
/// Jig brand tokens. The one signal color over the native graphite/vibrancy
/// surface; everything else stays semantic + system.
enum Brand {
    /// #FF6A1A — the single brand accent. Primary fills, selection, positive state.
    static let signalOrange = Color(red: 1.0, green: 0.416, blue: 0.102)
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Visual check**

Run the app (see `memory/worktree-gui-screenshot-howto`). Confirm: selection, primary "New" button, and rail "Settings" active state are now orange; the delete/trash actions are still red and read as clearly distinct from orange.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Theme.swift
git commit -m "feat: brand signal-orange accent token (replaces system accent)"
```

---

### Task 5: `JigMark` + `JigWordmark` + menubar template image

**Files:**
- Create: `Sources/WorktreeGUI/Brand/JigMark.swift`

**Interfaces:**
- Consumes: nothing (pure SwiftUI/AppKit).
- Produces:
  - `struct JigMark: View` — the clamp-J glyph, tinting with `foregroundStyle`.
  - `struct JigWordmark: View` — "Jig" in SF Pro Heavy, tight tracking, leading mark.
  - `enum JigGlyph { static func menuBarImage() -> NSImage }` — a template `NSImage` (~18pt) for the menubar.

- [ ] **Step 1: Implement the mark**

Create `Sources/WorktreeGUI/Brand/JigMark.swift`. The mark is a bold "J" whose hook grips a short bar — a clamp/vise reading. v1 geometry; refine visually in Step 3.

```swift
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
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Visual check + refine**

Temporarily preview the mark (or check it in the empty state after Task 7). Confirm the J + clamp bar reads as intentional at small sizes; nudge the `offset`/sizes in `JigMark` until it looks deliberate. Commit the tuned version.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Brand/JigMark.swift
git commit -m "feat: JigMark + JigWordmark + menubar template glyph"
```

---

### Task 6: Menubar glyph swap

**Files:**
- Modify: `Sources/WorktreeGUI/WorktreeGUIApp.swift`

**Interfaces:**
- Consumes: `JigGlyph.menuBarImage()`.

- [ ] **Step 1: Replace the system image with the Jig glyph**

Swap the `MenuBarExtra` initializer to a label-based one:

```swift
        MenuBarExtra {
            MenuContentView().environmentObject(state)
                .preferredColorScheme(.dark)
        } label: {
            Image(nsImage: JigGlyph.menuBarImage())
        }
        .menuBarExtraStyle(.window)
```

(was `MenuBarExtra("Worktrees", systemImage: "arrow.triangle.branch") { … }`)

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Visual check**

Run the app. Confirm the menubar now shows the clamp-J glyph (monochrome, tints with the menubar), not the old branch symbol.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/WorktreeGUIApp.swift
git commit -m "feat: menubar shows the Jig clamp-J glyph"
```

---

### Task 7: Localize + rebrand `MenuContentView` (+ `SidebarToggle`)

**Files:**
- Modify: `Sources/WorktreeGUI/Views/MenuContentView.swift`
- Modify: `Sources/WorktreeGUI/Theme.swift` (the `SidebarToggle` strings)

**Interfaces:**
- Consumes: `state.t(_:)`, `state.worktreeCountText(_:)`, `JigMark`, `JigWordmark`.

- [ ] **Step 1: Replace the hardcoded strings**

Apply these exact replacements in `MenuContentView.swift` (left = current literal → right = replacement):

- `Text("Depolar")` → `Text(state.t(.sidebarRepos))`
- `railButton("folder.badge.plus", label: "Repo ekle")` → `railButton("folder.badge.plus", label: state.t(.addRepo))`
- `railButton("gearshape", label: "Ayarlar", …)` → `label: state.t(.settings)`
- `railButton("power", label: "Çıkış")` → `label: state.t(.quit)`
- `.help("Yenile").accessibilityLabel("Yenile")` → `.help(state.t(.refresh)).accessibilityLabel(state.t(.refresh))`
- `Label("Yeni", systemImage: "plus")` → `Label(state.t(.new), systemImage: "plus")`
- `.help("Yeni worktree")` → `.help(state.t(.newWorktreeHelp))`
- `Text("Henüz worktree yok")` → `Text(state.t(.noWorktreesYet))`
- `Text("\u{201C}Yeni\u{201D} ile ilk worktree\u{2019}yi oluştur")` → `Text(state.t(.createFirstWorktree))`
- `Text("Sil?")` → `Text(state.t(.deletePrompt))`
- `pillButton("Worktree")` → `pillButton(state.t(.worktreeWord))`
- `pillButton("+ Branch", danger: true)` → `pillButton(state.t(.branchPlus), danger: true)`
- `rowAction("xmark", help: "Vazgeç")` → `rowAction("xmark", help: state.t(.cancel))`
- `rowAction("folder", help: "Finder")` → `rowAction("folder", help: state.t(.finder))`
- `rowAction("trash", help: "Sil", danger: true)` → `rowAction("trash", help: state.t(.delete), danger: true)`
- `Text(worktrees.count == 1 ? "1 worktree" : "\(worktrees.count) worktree")` → `Text(state.worktreeCountText(worktrees.count))`
- `Text("Repo yok")` → `Text(state.t(.noRepositories))`
- `Text("Yükleniyor…")` → `Text(state.t(.loading))`
- `Text("Soldaki \u{201C}Repo ekle\u{201D} ile bir klasör seç")` → `Text(state.t(.pickFolderHint))`

- [ ] **Step 2: Rebrand the empty states with the clamp-J**

In `emptyWorktrees`, replace the branch SF Symbol with the mark:

```swift
            JigMark()
                .frame(width: 26, height: 26)
                .foregroundStyle(Theme.textTertiary)
```

(was `Image(systemName: "arrow.triangle.branch").font(.system(size: 24))…`)

In `emptyState`, replace the leading symbol with the wordmark + tagline:

```swift
            JigWordmark(size: 22)
            Text(state.t(.noRepositories)).font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
```

(replaces the `Image(systemName: "arrow.triangle.branch")…` + `Text("Repo yok")` pair; keep the `if state.isRefreshing … else …` block below it, with its strings already localized in Step 1.)

- [ ] **Step 3: Localize `SidebarToggle` in `Theme.swift`**

In `SidebarToggle.body`, replace:

```swift
        .help(state.sidebarCollapsed ? state.t(.sidebarShow) : state.t(.sidebarHide))
        .accessibilityLabel(state.t(.sidebarLabel))
```

(was the Turkish `"Kenar çubuğunu göster/gizle"` / `"Kenar çubuğu"`)

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 5: Visual check**

Run the app. Confirm: sidebar header/rail tooltips and the worktree-count footer are English; the empty repo state shows the **Jig** wordmark; the empty-worktrees state shows the clamp-J mark.

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeGUI/Views/MenuContentView.swift Sources/WorktreeGUI/Theme.swift
git commit -m "feat: localize MenuContentView + rebrand empty states with Jig mark"
```

---

### Task 8: Localize `NewWorktreeView`

**Files:**
- Modify: `Sources/WorktreeGUI/Views/NewWorktreeView.swift`

**Interfaces:**
- Consumes: `state.t(_:)`.

- [ ] **Step 1: Replace the hardcoded strings**

Exact replacements:

- `Text("Yeni Worktree")` → `Text(state.t(.newWorktreeTitle))`
- `tabs: [(0, "Var olan branch"), (1, "Yeni branch")]` → `tabs: [(0, state.t(.existingBranch)), (1, state.t(.newBranchTab))]`
- `labeled("Branch")` → `labeled(state.t(.branch))`
- `labeled("Yeni branch adı")` → `labeled(state.t(.newBranchName))`
- `TextField("ör. feat/randevu", text: $newBranch)` → `TextField(state.t(.branchPlaceholder), text: $newBranch)`
- `labeled("Base branch (kopyalanacak)")` → `labeled(state.t(.baseBranch))`
- `labeled("Task adı (klasör)")` → `labeled(state.t(.taskNameFolder))`
- `TextField("ör. randevu", text: $taskName)` → `TextField(state.t(.taskPlaceholder), text: $taskName)`
- `Text(state.log.isEmpty ? "Çalışıyor…" : …)` → `Text(state.log.isEmpty ? state.t(.working) : state.log.joined(separator: "\n"))`
- `Button("Kapat")` → `Button(state.t(.close))`
- `Button("Vazgeç")` → `Button(state.t(.cancel))`
- `Label("Oluştur", systemImage: "plus")` → `Label(state.t(.create), systemImage: "plus")`

(`labeled(_:)` already takes a `String` title, so passing `state.t(...)` needs no signature change.)

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 3: Visual check**

Run the app, open **New**. Confirm every label, tab, placeholder, and button is English.

- [ ] **Step 4: Commit**

```bash
git add Sources/WorktreeGUI/Views/NewWorktreeView.swift
git commit -m "feat: localize NewWorktreeView strings"
```

---

### Task 9: Localize `SettingsView` + add the Language card

**Files:**
- Modify: `Sources/WorktreeGUI/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `state.t(_:)`, `state.language`, `state.setLanguage(_:)`, `Language`.

- [ ] **Step 1: Replace the hardcoded strings**

Exact replacements:

- `Text("Ayarlar")` → `Text(state.t(.settingsTitle))`
- `section("Repo Kaynakları", "Klasör seç: …")` → `section(state.t(.repoSourcesTitle), state.t(.repoSourcesCaption))`
- `Text("Henüz kaynak yok")` → `Text(state.t(.noSourcesYet))`
- `sourceRow($0, kind: "kök")` → `sourceRow($0, kind: state.t(.kindRoot))`
- `sourceRow($0, kind: "repo")` → `sourceRow($0, kind: state.t(.kindRepo))`
- `Label("Finder'dan Ekle", systemImage: "folder.badge.plus")` → `Label(state.t(.addFromFinder), systemImage: "folder.badge.plus")`
- `section("Tarama Derinliği", "Kök altında…")` → `section(state.t(.scanDepthTitle), state.t(.scanDepthCaption))`
- `section("Terminal", "Worktree hangi terminalde açılsın")` → `section(state.t(.terminalTitle), state.t(.terminalCaption))`
- `section("Editör", "Worktree hangi editörde açılsın")` → `section(state.t(.editorTitle), state.t(.editorCaption))`
- `section("Paket Yöneticisi", "Seçili repolarda…")` → `section(state.t(.packageManagerTitle), state.t(.packageManagerCaption))`
- `Text("Repo bulunamadı")` → `Text(state.t(.noReposFound))`
- `section("Terminal Başlangıç Komutu", "Terminal açılınca…")` → `section(state.t(.startupCommandTitle), state.t(.startupCommandCaption))`
- `TextField("ör. npm run dev", text: …)` → `TextField(state.t(.startupPlaceholder), text: …)`
- `Text("Env/komut kuralları için config.json'ı elle düzenle:")` → `Text(state.t(.editConfigHint))`
- In `packageManagerRow`: `Text("Yok").tag("none")` → `Text(state.t(.pmNone)).tag("none")`
- In `sourceRow`: `.help("Kaldır")` → `.help(state.t(.remove))`

Note: the `sourceRow(_:kind:)` `kind` param is now a display string. Its internal `Image(systemName: kind == "repo" ? "shippingbox" : "folder")` comparison breaks once localized — fix in Step 2.

- [ ] **Step 2: Make `sourceRow` icon choice language-independent**

Change `sourceRow(_:kind:)` to take an explicit `isRepo` flag instead of comparing the localized string:

```swift
    @ViewBuilder
    private func sourceRow(_ path: String, kind: String, isRepo: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isRepo ? "shippingbox" : "folder")
```

Update the two call sites:

```swift
                        ForEach(state.config.scanRoots, id: \.self) { sourceRow($0, kind: state.t(.kindRoot), isRepo: false) }
                        ForEach(state.config.manualRepos, id: \.self) { sourceRow($0, kind: state.t(.kindRepo), isRepo: true) }
```

- [ ] **Step 3: Add the Language card**

Add a new `section` as the first card under the title (above "Repository Sources"):

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

Add `import WorktreeCore` is already present (file already imports it).

- [ ] **Step 4: Verify build**

Run: `swift build`
Expected: Builds with no errors.

- [ ] **Step 5: Visual check — the language toggle**

Run the app, open **Settings**. Confirm: all sections are English; the **Language** card shows `English | Türkçe`. Switch to **Türkçe** — the entire UI re-renders in Turkish (this exercises the whole L10n path). Switch back to English.

- [ ] **Step 6: Commit**

```bash
git add Sources/WorktreeGUI/Views/SettingsView.swift
git commit -m "feat: localize SettingsView + add Language (EN/TR) card"
```

---

### Task 10: App display name → "Jig"

**Files:**
- Modify: `scripts/build-app.sh`

**Interfaces:** none.

- [ ] **Step 1: Rename the display name**

In `build-app.sh`, change the display name (the bundle identifier and binary name stay, to avoid orphaning the existing config):

```bash
APP_DISPLAY="Jig"
```

(was `APP_DISPLAY="Worktree GUI"`)

- [ ] **Step 2: Rebuild the bundle**

Run: `./scripts/build-app.sh`
Expected: `OK: built …/WorktreeGUI.app`; `CFBundleDisplayName` is now "Jig".

- [ ] **Step 3: Commit**

```bash
git add scripts/build-app.sh
git commit -m "feat: app display name is Jig"
```

---

### Task 11: Final verification pass

**Files:** none (verification only).

- [ ] **Step 1: Full test suite**

Run: `swift test`
Expected: All `WorktreeCoreTests` pass (Config + L10n included).

- [ ] **Step 2: Release build + bundle**

Run: `swift build -c release && ./scripts/build-app.sh`
Expected: Both succeed.

- [ ] **Step 3: Visual acceptance (run the app)**

Per `memory/worktree-gui-screenshot-howto`, launch and screenshot. Confirm against the spec's success criteria:
- Menubar shows the clamp-J glyph.
- Orange `#FF6A1A` is the single accent everywhere; no system-blue accent remains.
- Destructive (trash / "+ Branch" / remove-source) is red and clearly distinct from orange.
- Vibrancy, SF Pro, SF Mono-for-code, source-list, and Reduce-Motion behaviors intact.
- UI is English by default; the Settings Language card flips the whole UI to Turkish and back.
- The empty states show the Jig wordmark / mark.

- [ ] **Step 4: Update the design-direction memory**

Append to `memory/worktree-gui-design-direction.md` (and its MEMORY.md hook) that the app is now branded **Jig**: clamp-J mark, `signalOrange #FF6A1A` accent replacing the system accent, EN-default + TR-toggle localization via `WorktreeCore/L10n`. Note the earlier "follow the system, don't brand it" rule is superseded by the brand accent (vibrancy + SF Pro + HIG still hold).

---

## Self-Review

**Spec coverage:**
- §2 Name/personality/tagline → Tasks 5 (wordmark), 10 (display name); tagline copy lives in `createFirstWorktree`/wordmark usage (Tasks 2, 7).
- §2 Mark (clamp-J menubar glyph + wordmark) → Tasks 5, 6, 7. ✔
- §3 Color (orange accent, vibrancy preserved, orange≠destructive) → Task 4 + visual checks in 4/11. ✔
- §4 Typography (SF Pro/SF Mono unchanged, wordmark Heavy) → Task 5; no mono/accent change needed elsewhere. ✔
- §5 Voice & Localization (EN default, TR toggle, i18n layer, Config.language, Settings card) → Tasks 1, 2, 3, 7, 8, 9. ✔
- §6 UI revision scope (Theme, menubar, sidebar/rows, headers, buttons, empty state, LiquidTabs, i18n, build-app) → Tasks 4–10. **LiquidTabs orange tint:** auto-satisfied — `GlassIndicator`/fallback already use `Theme.accent`, which becomes orange in Task 4 (no separate edit needed). **Buttons** (`AccentPill`) likewise read `Theme.accent` → orange via Task 4. Noted, no gap.
- §7 Out of scope (no logic/target/bundle-id/config-path rename) → respected; Task 10 changes display name only. ✔
- §8 Success criteria → Task 11 checklist mirrors them. ✔

**Placeholder scan:** No TBD/TODO/"add error handling"/"similar to". Every code step shows full code or exact old→new replacements. ✔

**Type consistency:** `L10nKey` cases referenced in Tasks 7–9 all exist in the Task 2 enum (cross-checked: `sidebarRepos, addRepo, settings, quit, refresh, new, newWorktreeHelp, noWorktreesYet, createFirstWorktree, deletePrompt, worktreeWord, branchPlus, cancel, finder, delete, noRepositories, loading, pickFolderHint, newWorktreeTitle, existingBranch, newBranchTab, branch, newBranchName, branchPlaceholder, baseBranch, taskNameFolder, taskPlaceholder, working, close, create, settingsTitle, repoSourcesTitle, repoSourcesCaption, noSourcesYet, kindRoot, kindRepo, addFromFinder, scanDepthTitle, scanDepthCaption, terminalTitle, terminalCaption, editorTitle, editorCaption, packageManagerTitle, packageManagerCaption, noReposFound, startupCommandTitle, startupCommandCaption, startupPlaceholder, editConfigHint, pmNone, remove, languageTitle, languageCaption, sidebarShow, sidebarHide, sidebarLabel, addPanelPrompt, addPanelMessage`). `state.t/worktreeCountText/language/setLanguage` defined in Task 3 before first use in Tasks 7–9. `sourceRow` signature change (Task 9 Step 2) updates both call sites. ✔
