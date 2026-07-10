# Açılışta Başlat (Login Item) — Tasarım

**Tarih:** 2026-07-10
**Durum:** Onaylandı

## Amaç

Menubar app için beklenen "sistemle birlikte başlat" seçeneği. `SMAppService.mainApp` ile.

## Tasarım

- **`Sources/Twig/LoginItem.swift`** — `import ServiceManagement`. `SMAppService.mainApp` sarmalayıcı:
  - `var isEnabled: Bool` → `SMAppService.mainApp.status == .enabled`.
  - `func setEnabled(_ on: Bool)` → `on ? try register() : try unregister()`. Hata yut (log).
- **`SettingsView`** — "Terminal & Editör" civarına yeni `SettingsRow(title: launchAtLoginTitle)` + `TwigToggle`. Toggle binding: get `LoginItem.isEnabled`, set `LoginItem.setEnabled($0)`.
- **Persistence yok** — durum sistemce tutulur (config'e yazılmaz). Toggle her görünümde canlı status okur.
- **L10n:** `launchAtLoginTitle`, `launchAtLoginCaption` TR/EN.

## Kısıtlar

- macOS 13+ API (proje macOS 14 — uygun).
- `SMAppService` yalnız imzalı/bundled app'te güvenilir; `/Applications/Twig.app`'ten çalışırken doğru davranır (ad-hoc imza yeterli).

## Test

Yok. `SMAppService` sistem API'si; ProcessRunner seam'i yok, GUI-only. TDD istisnası — test edilebilir saf mantık içermiyor.

## Dosya dokunuş özeti

- `Sources/Twig/LoginItem.swift` — yeni.
- `Sources/Twig/Views/SettingsView.swift` — toggle satırı.
- `Sources/TwigCore/L10n/L10n.swift` — 2 anahtar TR/EN.
