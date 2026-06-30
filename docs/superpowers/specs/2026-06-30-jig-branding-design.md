# Jig — Branding & Design System

**Date:** 2026-06-30
**Status:** Approved (design), pending implementation plan
**Scope:** Rebrand the menubar app currently named "WorktreeGUI" to **Jig**, define a brand identity and design system, and revise the UI to express it — without abandoning the established Apple-native skeleton (native vibrancy, SF Pro, macOS HIG).

---

## 1. Background

The app is a macOS menubar-only tool (`LSUIElement`/`.accessory`) for creating and managing `git worktree`s across many local repos: scan roots, pick a repo, create a worktree on a new/existing branch, apply `.env` rules, run package-manager install + setup commands, and open the worktree in an editor/terminal.

The current visual direction (memory: `worktree-gui-design-direction`) is intentionally **un-branded** — "as if Apple officially designed it": system accent (`Color.accentColor`), native vibrancy via `NSVisualEffectView`, SF Pro chrome, SF Mono for code, source-list sidebar, 8pt grid.

The user has chosen a **full identity revision**: the app gains a distinct brand (name, mark, color, type tone, voice) layered onto the native skeleton — native bones, one clear brand signature, no HIG violations.

## 2. Brand

### Name
**Jig.**

Rationale: a *jig* is a workshop fixture that holds work for fast, repeatable, identical setups — exactly what the app does for each task (repeatable worktree setup: worktree + env rules + install + dev server). Also "jig" = a lively, quick dance → energy/speed. One syllable, hard *G*, ownable.

> Trademark / domain availability is unverified and must be checked separately before any public release.

### Personality
Workshop precision. Sharp, fast, exact. Quiet confidence — an engineer's tool, not playful-cute. "Set it up once, clamp it, repeat instantly."

### Tagline
Primary: **"Spin up a worktree."** (imperative, fast). Alternates: "A jig for your repos." / "Repeatable workspaces, instantly."

### Mark
**Clamp-J monogram** (concept "F"): the letter **J** read as a clamp/vise squeezing a bar — typography + tool in one glyph.

- **Menubar glyph:** a monochrome **template image** version of the clamp-J at 16pt, so it tints like a native menubar symbol and sits naturally beside SF Symbols. Replaces the current `arrow.triangle.branch` system image.
- **Wordmark:** "Jig" set in SF Pro Heavy, tight tracking; the clamp corner of the J is the brand signature. Appears in pane/about headers and the empty state.

## 3. Color

Industrial: a **graphite neutral** carrying one **signal** accent.

| Token | Value | Use |
|-------|-------|-----|
| `signalOrange` | `#FF6A1A` | The one brand signal — primary action fill, selection, positive state, accents |
| graphite ramp | dark neutral (vibrancy material tone) | Surfaces/neutrals |
| `danger` | `Color(nsColor: .systemRed)` | Destructive only — unchanged |

Key decisions:
- **Vibrancy is preserved.** "Graphite" is the dark tone the vibrancy material already reads as — *not* a hardcoded opaque background. The desktop still bleeds through (Control-Center look). Reduce-transparency fallback stays.
- **Orange replaces the system accent.** The app no longer follows `Color.accentColor`; the brand owns its hue. `Theme.accent` becomes `signalOrange`.
- **Orange ≠ destructive.** `#FF6A1A` and `systemRed` are hue-adjacent, so orange is reserved for primary/positive emphasis; delete/destructive actions stay red. The two must be visually verified side-by-side (e.g. delete button next to a primary button) to confirm they don't read as the same family.

## 4. Typography

- **SF Pro** for all chrome — unchanged (native, HIG).
- **SF Mono** reserved for real "code" content only — branch names, folder names, paths. Unchanged (`Theme.mono`).
- **Wordmark** "Jig": SF Pro Heavy, tight tracking.
- Orange is never applied to mono/code text; it is an emphasis/state color only.

## 5. Voice & Localization

- **Voice:** sharp imperative verbs ("Spin up", "Open", "Remove"), short, tool-y, no hedging.
- **Default language: English.** A **Turkish** option is selectable in Settings.
- This requires an **i18n layer**. Today, user-facing strings are hardcoded inline (mostly Turkish). They must be extracted into an EN/TR string table behind a lookup (e.g. `L10n.string(...)`).
- `Config` gains a `language` field (`"en"` default), decoded resiliently like the other keys (missing → default).
- Settings gains a **"Language / Dil"** card to switch language; the UI reflects the change.

## 6. UI revision scope

The native skeleton (vibrancy, SF Pro, source-list sidebar, 8pt grid, micro-animations gated on Reduce Motion, HIG) stays. Concrete changes:

**`Theme.swift`**
- Add a `Brand` token group: `signalOrange = #FF6A1A`, graphite ramp.
- `Theme.accent` → `signalOrange` (no longer `Color.accentColor`). `danger` stays `systemRed`.
- Add clamp-J mark + wordmark assets/drawing.

**Menubar (`WorktreeGUIApp`)**
- App/menubar icon: `arrow.triangle.branch` → clamp-J **template** glyph (16pt monochrome).

**Sidebar / rows (`MenuContentView`)**
- Source-list layout unchanged; selection highlight and repo-box accent use orange.

**Headers / about**
- Show the **Jig** wordmark (SF Pro Heavy, tight tracking).

**Buttons (`Theme.swift` styles)**
- `AccentPill` → orange fill, white label. `GhostPill` unchanged. Destructive actions never orange → red.

**Empty state**
- Clamp-J motif + tagline "Spin up a worktree."

**`LiquidTabs`**
- Selected indicator tinted orange.

**Localization (cross-cutting)**
- New `L10n` layer with EN/TR tables.
- `Config.language` field + resilient decode.
- Settings "Language / Dil" card.
- Every visible string routed through `L10n`.

**App bundle / metadata (`scripts/build-app.sh`)**
- Display name → "Jig". (Bundle identifier change is optional and out of scope unless the user wants it; renaming the identifier orphans the existing `~/.config/worktree-gui/config.json`.)

## 7. Out of scope

- Functional/behavioral changes to worktree creation, scanning, or setup logic.
- Renaming the Swift targets/modules (`WorktreeGUI`/`WorktreeCore`), the config path, or the bundle identifier — cosmetic rename only at the display layer unless the user asks.
- Trademark/domain registration.
- A full custom icon-set / app store assets beyond the menubar glyph + wordmark.

## 8. Success criteria

- App presents as **Jig**: clamp-J menubar glyph, wordmark in headers/empty state.
- Orange `#FF6A1A` is the single accent throughout; system blue no longer appears as the app's accent; destructive stays red and is clearly distinct.
- Vibrancy, SF Pro, SF Mono-for-code, source-list, and HIG behaviors are intact.
- UI is English by default; switching to Turkish in Settings re-renders all visible strings.
- Verified **visually by running the app** (not just building) on the dark vibrancy surface — per the project's design-verification practice.
